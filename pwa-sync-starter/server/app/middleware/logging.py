"""
server/app/middleware/logging.py

Request/response logging middleware for audit trail.
Logs all API activity while redacting sensitive information.
"""

import logging
import uuid
import time
import json
from fastapi import Request
from typing import Callable, Optional, Dict, Any
from datetime import datetime

logger = logging.getLogger("audit")
perf_logger = logging.getLogger("performance")


# Sensitive fields that should never appear in logs
REDACTED_FIELDS = {
    # Authentication
    'password', 'token', 'authorization', 'secret', 'key',
    'client_secret', 'access_token', 'refresh_token',
    'bearer', 'api_key', 'oauth_token', 'jwt',
    # PII
    'ssn', 'credit_card', 'pin', 'cvv', 'tax_id',
    # Private keys
    'private_key', 'rsa_key', 'dsa_key',
    # Salesforce
    'sf_user_id', 'instance_url', 'consumer_key', 'consumer_secret',
}

# Endpoints that should not be logged in detail (too verbose)
EXCLUDED_ENDPOINTS = {
    '/health',
    '/docs',
    '/openapi.json',
    '/redoc',
}

# Endpoints that are especially sensitive
SENSITIVE_ENDPOINTS = {
    '/api/auth',
    '/api/sync/upload',
    '/api/device',
}


def redact_value(value: str, field_name: str) -> str:
    """
    Redact a single value if it matches sensitive field names.
    
    Args:
        value: Value to potentially redact
        field_name: Field name to check
    
    Returns:
        Original or redacted value
    """
    if any(sensitive in field_name.lower() for sensitive in REDACTED_FIELDS):
        if isinstance(value, str) and len(value) > 10:
            # Show first and last few chars for context
            return f"{value[:4]}...{value[-4:]}"
        return "***REDACTED***"
    return value


def redact_dict_recursive(data: Any, depth: int = 0, max_depth: int = 3) -> Any:
    """
    Recursively redact sensitive fields from dictionaries and lists.
    
    Args:
        data: Data structure to redact
        depth: Current recursion depth
        max_depth: Maximum recursion depth
    
    Returns:
        Data with sensitive fields redacted
    """
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
        return [redact_dict_recursive(item, depth + 1, max_depth) for item in data[:10]]  # Limit list size
    
    else:
        return data


def extract_request_body(request: Request, max_size: int = 1000) -> Optional[str]:
    """
    Safely extract request body for logging without fully consuming it.
    Note: Request body can only be read once in FastAPI, so this should be used carefully.
    Consider storing body in request.state if needed by other middleware.
    """
    try:
        # Check if body was pre-cached in request state
        if hasattr(request.state, 'body'):
            body = request.state.body
            if isinstance(body, bytes):
                body_str = body.decode('utf-8', errors='replace')
            else:
                body_str = str(body)
            
            if len(body_str) > max_size:
                body_str = body_str[:max_size] + "..."
            
            return body_str
    except Exception:
        pass
    
    return None


class RequestIDMiddleware:
    """
    Adds a unique request ID to each request for correlation.
    Should be registered as the first middleware.
    """
    
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
    Logs all API requests and responses for audit trail.
    Automatically redacts sensitive information.
    """
    
    def __init__(self, app):
        self.app = app
    
    async def __call__(self, request: Request, call_next: Callable):
        # Skip logging for excluded endpoints
        if any(request.url.path.startswith(excluded) for excluded in EXCLUDED_ENDPOINTS):
            return await call_next(request)
        
        # Get or generate request ID
        request_id = getattr(request.state, 'request_id', str(uuid.uuid4()))
        start_time = time.time()
        
        # Extract request info
        method = request.method
        path = request.url.path
        query_params = dict(request.query_params) if request.query_params else {}
        client_ip = request.client.host if request.client else "unknown"
        user_agent = request.headers.get("user-agent", "unknown")
        
        # Check if sensitive endpoint
        is_sensitive = any(path.startswith(sensitive) for sensitive in SENSITIVE_ENDPOINTS)
        
        # Log request
        log_data = {
            "request_id": request_id,
            "type": "HTTP_REQUEST",
            "timestamp": datetime.utcnow().isoformat(),
            "method": method,
            "path": path,
            "client_ip": client_ip,
            "user_agent": user_agent[:100],  # Truncate UA string
        }
        
        if query_params and not is_sensitive:
            log_data["query_params"] = redact_dict_recursive(query_params)
        
        logger.info(json.dumps(log_data))
        
        # Process request
        try:
            response = await call_next(request)
        except Exception as exc:
            # Log exception but don't expose details
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
        
        # Log response
        duration_ms = (time.time() - start_time) * 1000
        
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
        
        return response


def setup_audit_logging(app):
    """
    Register audit logging middleware and configure loggers.
    
    Args:
        app: FastAPI application instance
    
    Example:
        from fastapi import FastAPI
        from .middleware.logging import setup_audit_logging
        
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
