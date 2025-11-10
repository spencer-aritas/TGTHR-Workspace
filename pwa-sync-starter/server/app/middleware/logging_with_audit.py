"""
server/app/middleware/logging_with_audit.py

Enhanced request/response logging middleware that sends all PHI access to Salesforce.

This middleware:
1. Logs all requests to local logger (monitoring/debugging)
2. Sends PHI-related requests to Salesforce Audit_Log__c (compliance archive)
3. Automatically redacts sensitive information
4. Provides request correlation IDs

Result: Single source of truth in Salesforce for all audit events.
"""

import logging
import uuid
import time
import json
from fastapi import Request
from typing import Callable, Optional
from datetime import datetime

logger = logging.getLogger("audit")
perf_logger = logging.getLogger("performance")


# Sensitive fields that should never appear in logs
REDACTED_FIELDS = {
    'password', 'token', 'authorization', 'secret', 'key',
    'client_secret', 'access_token', 'refresh_token',
    'bearer', 'api_key', 'oauth_token', 'jwt',
    'ssn', 'credit_card', 'pin', 'cvv', 'tax_id',
    'private_key', 'rsa_key', 'dsa_key',
    'sf_user_id', 'instance_url', 'consumer_key', 'consumer_secret',
}

# Endpoints that are excluded from logging
EXCLUDED_ENDPOINTS = {
    '/health',
    '/docs',
    '/openapi.json',
    '/redoc',
}

# Endpoints that are especially sensitive (PHI access)
SENSITIVE_ENDPOINTS = {
    '/api/auth',
    '/api/sync/upload',
    '/api/device',
    '/api/quick-person-account',
    '/api/interaction-summary',
    '/api/cases',
}


def redact_value(value: str, field_name: str) -> str:
    """Redact a single value if it matches sensitive field names."""
    if any(sensitive in field_name.lower() for sensitive in REDACTED_FIELDS):
        if isinstance(value, str) and len(value) > 10:
            return f"{value[:4]}...{value[-4:]}"
        return "***REDACTED***"
    return value


def redact_dict_recursive(data, depth: int = 0, max_depth: int = 3):
    """Recursively redact sensitive fields from dictionaries and lists."""
    if depth >= max_depth:
        return "[REDACTED - MAX DEPTH]"
    
    if isinstance(data, dict):
        redacted = {}
        for key, value in data.items():
            if any(sensitive in key.lower() for sensitive in REDACTED_FIELDS):
                redacted[key] = "***REDACTED***"
            elif isinstance(value, (dict, list)):
                redacted[key] = redact_dict_recursive(value, depth + 1, max_depth)
            else:
                redacted[key] = value
        return redacted
    
    elif isinstance(data, list):
        return [redact_dict_recursive(item, depth + 1, max_depth) for item in data[:10]]
    
    else:
        return data


class RequestIDMiddleware:
    """Adds a unique request ID to each request for correlation."""
    
    def __init__(self, app):
        self.app = app
    
    async def __call__(self, request: Request, call_next: Callable):
        # Generate unique request ID
        request_id = str(uuid.uuid4())
        request.state.request_id = request_id
        
        # Add to response headers
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        
        return response


class AuditLoggingMiddleware:
    """
    Logs all API requests/responses.
    
    For PHI-related endpoints, also creates Salesforce Audit_Log__c records.
    This ensures single source of truth in Salesforce for compliance.
    """
    
    def __init__(self, app):
        self.app = app
        self.audit_integration = None  # Lazy load
    
    def _get_audit_integration(self):
        """Lazy load audit integration to avoid circular imports"""
        if self.audit_integration is None:
            from .audit_integration import audit_integration
            self.audit_integration = audit_integration
        return self.audit_integration
    
    async def __call__(self, request: Request, call_next: Callable):
        # Skip logging for excluded endpoints
        if any(request.url.path.startswith(excluded) for excluded in EXCLUDED_ENDPOINTS):
            return await call_next(request)
        
        # Get request ID (set by RequestIDMiddleware)
        request_id = getattr(request.state, 'request_id', str(uuid.uuid4()))
        start_time = time.time()
        
        # Extract request info
        method = request.method
        path = request.url.path
        query_params = dict(request.query_params) if request.query_params else {}
        client_ip = request.client.host if request.client else "unknown"
        user_agent = request.headers.get("user-agent", "unknown")[:100]
        
        # Check if sensitive endpoint (PHI access)
        is_sensitive = any(path.startswith(sensitive) for sensitive in SENSITIVE_ENDPOINTS)
        
        # Log request
        log_data = {
            "request_id": request_id,
            "type": "HTTP_REQUEST",
            "timestamp": datetime.utcnow().isoformat(),
            "method": method,
            "path": path,
            "client_ip": client_ip,
            "user_agent": user_agent,
        }
        
        if query_params and not is_sensitive:
            log_data["query_params"] = redact_dict_recursive(query_params)
        
        logger.info(json.dumps(log_data))
        
        # Process request
        try:
            response = await call_next(request)
        except Exception as exc:
            # Log exception
            logger.error(
                json.dumps({
                    "request_id": request_id,
                    "type": "HTTP_ERROR",
                    "timestamp": datetime.utcnow().isoformat(),
                    "method": method,
                    "path": path,
                    "exception": type(exc).__name__,
                    "client_ip": client_ip,
                })
            )
            raise
        
        # Calculate duration
        duration_ms = (time.time() - start_time) * 1000
        
        # Log response
        log_data = {
            "request_id": request_id,
            "type": "HTTP_RESPONSE",
            "timestamp": datetime.utcnow().isoformat(),
            "method": method,
            "path": path,
            "status_code": response.status_code,
            "duration_ms": round(duration_ms, 2),
        }
        
        logger.info(json.dumps(log_data))
        
        # Log performance for slow requests
        if duration_ms > 1000:
            perf_logger.warning(
                json.dumps({
                    "request_id": request_id,
                    "message": "Slow request",
                    "path": path,
                    "duration_ms": round(duration_ms, 2),
                })
            )
        
        # ===== CRITICAL: Log to Salesforce audit trail =====
        # This ensures single source of truth for PHI access
        try:
            audit = self._get_audit_integration()
            audit.log_api_access(
                request=request,
                response_status=response.status_code,
                user_id=getattr(request.state, 'user_id', None),
                entity_ids=getattr(request.state, 'entity_ids', None),
                duration_ms=duration_ms,
                request_id=request_id,
                error_detail=None if response.status_code < 400 else f"HTTP {response.status_code}",
            )
        except Exception as e:
            logger.error(f"Failed to log to Salesforce audit trail: {str(e)}", exc_info=True)
            # Don't raise - continue processing
        
        response.headers["X-Request-ID"] = request_id
        return response


def setup_audit_logging(app):
    """
    Register audit logging middleware and configure loggers.
    
    This setup ensures:
    - All requests logged locally (monitoring)
    - All PHI access logged to Salesforce (compliance)
    - Single source of truth in Salesforce
    
    Args:
        app: FastAPI application instance
    
    Example:
        from fastapi import FastAPI
        from .middleware.logging_with_audit import setup_audit_logging
        
        app = FastAPI()
        setup_audit_logging(app)
    """
    # Add middleware (in reverse order - first added runs last)
    app.add_middleware(AuditLoggingMiddleware)
    app.add_middleware(RequestIDMiddleware)
    
    # Configure logging
    audit_handler = logging.StreamHandler()
    audit_handler.setFormatter(logging.Formatter('%(message)s'))
    logger.addHandler(audit_handler)
    logger.setLevel(logging.INFO)
    
    perf_logger.addHandler(audit_handler)
    perf_logger.setLevel(logging.WARNING)
