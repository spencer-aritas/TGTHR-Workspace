"""
server/app/middleware/audit_integration.py

Integration layer between API middleware logging and Salesforce audit trail.
Ensures all API activity is captured in Salesforce Audit_Log__c as single source of truth.

This module bridges:
  - FastAPI request/response logging (real-time monitoring)
  - Salesforce Audit_Log__c records (HIPAA-compliant archive)
  
Guarantees one authoritative audit trail in Salesforce for all PHI access.
"""

import logging
from typing import Optional, Dict, Any
from datetime import datetime, timezone
from fastapi import Request

logger = logging.getLogger("audit_integration")


# Endpoints that access PHI (Personally Identifiable/Health Information)
PHI_ACCESS_PATTERNS = {
    # Person/Account data
    '/api/quick-person-account': 'CREATE_PERSON',
    '/api/person': 'ACCESS_PERSON',
    '/api/sync': 'SYNC_DATA',
    
    # Interaction/Clinical notes
    '/api/interaction-summary': 'ACCESS_INTERACTION',
    '/api/cases': 'ACCESS_CASE',
    
    # Assessment data (sensitive)
    '/api/ssrs': 'ACCESS_ASSESSMENT',
    
    # Disbursement/Benefits (financial + personal)
    '/api/benefits': 'ACCESS_BENEFITS',
    '/api/disburse': 'DISBURSE_BENEFIT',
}

# Non-PHI endpoints (don't log to audit trail)
NON_PHI_ENDPOINTS = {
    '/health',
    '/api/health',
    '/docs',
    '/openapi.json',
    '/redoc',
}


class AuditIntegration:
    """
    Bridge between API logging and Salesforce audit trail.
    
    Usage:
        audit = AuditIntegration()
        audit.log_api_access(
            request=request,
            response_status=response.status_code,
            user_id=user_id,
            entity_ids=[person_id, case_id],
            duration_ms=156.2
        )
    """
    
    def __init__(self):
        """Initialize with Salesforce audit logger"""
        from ..salesforce.audit_log_service import audit_logger
        self.audit_logger = audit_logger
    
    def log_api_access(
        self,
        request: Request,
        response_status: int,
        user_id: Optional[str] = None,
        entity_ids: Optional[list[str]] = None,
        duration_ms: float = 0.0,
        request_id: Optional[str] = None,
        error_detail: Optional[str] = None,
    ) -> None:
        """
        Log API access to Salesforce audit trail.
        
        Args:
            request: FastAPI Request object
            response_status: HTTP status code from response
            user_id: Salesforce user ID (who made the request)
            entity_ids: List of record IDs accessed (person, case, etc.)
            duration_ms: Request duration in milliseconds
            request_id: Unique request correlation ID
            error_detail: Error message if request failed
        
        Example:
            audit.log_api_access(
                request=request,
                response_status=200,
                user_id="user@example.com",
                entity_ids=["001D000000IRFmaIAH"],  # Salesforce account ID
                duration_ms=145.2,
                request_id="550e8400-e29b-41d4-a716-446655440000"
            )
        """
        # Check if endpoint accesses PHI
        if not self._is_phi_endpoint(request.url.path):
            return  # Don't log non-PHI endpoints
        
        try:
            # Determine action type
            action_type = self._get_action_type(request)
            event_type = self._get_event_type(response_status)
            
            # Determine which entity was accessed
            primary_entity_id = entity_ids[0] if entity_ids else None
            
            # Build audit details
            details = self._build_audit_details(
                request=request,
                response_status=response_status,
                duration_ms=duration_ms,
                entity_count=len(entity_ids) if entity_ids else 0,
            )
            
            # Build audit JSON for extended context
            audit_json = {
                "request_id": request_id,
                "method": request.method,
                "path": str(request.url.path),
                "query_params": dict(request.query_params) if request.query_params else None,
                "status_code": response_status,
                "duration_ms": round(duration_ms, 2),
                "entity_count": len(entity_ids) if entity_ids else 0,
                "entities_accessed": entity_ids if entity_ids else [],
            }
            
            # Add error details if present
            if error_detail:
                audit_json["error"] = error_detail
                audit_json["error_type"] = "FAILED_ACCESS_ATTEMPT"
            
            # Log to Salesforce
            self.audit_logger.log_action(
                action_type=action_type,
                entity_id=primary_entity_id,
                details=details,
                user_id=user_id,
                application="PWA",
                audit_json=audit_json,
                event_type=event_type,
                source_ip=self._get_client_ip(request),
                status="SUCCESS" if response_status < 400 else "FAILURE",
                timestamp=datetime.now(timezone.utc).isoformat(),
                compliance_reference=request_id,
            )
            
            logger.debug(
                f"Audit log created: {action_type} on {primary_entity_id} "
                f"by {user_id} (status: {response_status})"
            )
            
        except Exception as e:
            logger.error(
                f"Failed to create audit log for {request.url.path}: {str(e)}",
                exc_info=True
            )
    
    def _is_phi_endpoint(self, path: str) -> bool:
        """
        Check if this endpoint accesses PHI (Personally Identifiable/Health Information).
        
        Returns True if path matches any PHI patterns, False for non-PHI endpoints.
        """
        # Skip non-PHI endpoints
        if any(path.startswith(excluded) for excluded in NON_PHI_ENDPOINTS):
            return False
        
        # Check if path matches PHI patterns
        return any(path.startswith(pattern) for pattern in PHI_ACCESS_PATTERNS.keys())
    
    def _get_action_type(self, request: Request) -> str:
        """Determine audit action type from HTTP method and path."""
        method = request.method.upper()
        path = request.url.path
        
        # Check for specific endpoint patterns
        for pattern, action in PHI_ACCESS_PATTERNS.items():
            if path.startswith(pattern):
                # Combine pattern action with HTTP method
                if method == "POST":
                    return f"{action}_CREATE"
                elif method == "PUT" or method == "PATCH":
                    return f"{action}_MODIFY"
                elif method == "DELETE":
                    return f"{action}_DELETE"
                else:  # GET, HEAD, OPTIONS
                    return action
        
        # Fallback based on method
        method_actions = {
            "GET": "VIEW",
            "POST": "CREATE",
            "PUT": "MODIFY",
            "PATCH": "MODIFY",
            "DELETE": "DELETE",
        }
        return method_actions.get(method, "OTHER")
    
    def _get_event_type(self, status_code: int) -> str:
        """Determine event type based on HTTP status code."""
        if status_code < 300:
            return "ACCESS"  # Success
        elif status_code < 400:
            return "ACCESS"  # Still successful (redirect, etc)
        elif status_code == 401 or status_code == 403:
            return "ATTEMPT"  # Failed auth/permission
        else:
            return "ATTEMPT"  # Other failures
    
    def _get_client_ip(self, request: Request) -> str:
        """Extract client IP from request, checking X-Forwarded-For."""
        # Check for X-Forwarded-For (if behind proxy)
        if forwarded := request.headers.get("x-forwarded-for"):
            return forwarded.split(",")[0].strip()
        
        # Fallback to direct connection IP
        if request.client:
            return request.client.host
        
        return "unknown"
    
    def _build_audit_details(
        self,
        request: Request,
        response_status: int,
        duration_ms: float,
        entity_count: int,
    ) -> str:
        """Build human-readable audit details string."""
        status_text = "SUCCESS" if response_status < 400 else "FAILURE"
        
        details = (
            f"{request.method} {request.url.path} - {status_text} ({response_status})"
        )
        
        if entity_count > 0:
            details += f" - {entity_count} entities accessed"
        
        details += f" - {duration_ms:.0f}ms"
        
        return details


# Global instance for easy access
audit_integration = AuditIntegration()
