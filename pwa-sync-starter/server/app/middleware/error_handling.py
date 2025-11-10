"""
server/app/middleware/error_handling.py

Centralized error handling and security exception classes.
Prevents leaking sensitive information in error responses.
"""

import logging
import traceback
from typing import Any, Dict, Optional
from fastapi import Request, status
from fastapi.responses import JSONResponse
from pydantic import ValidationError

logger = logging.getLogger("error_handling")


class SecurityException(Exception):
    """
    Custom exception for security-related errors.
    Separates user-facing message from detailed logging.
    """
    def __init__(
        self,
        message: str,
        log_detail: Optional[str] = None,
        status_code: int = status.HTTP_400_BAD_REQUEST,
        error_code: str = "SECURITY_ERROR"
    ):
        self.message = message  # User-facing message
        self.log_detail = log_detail or message  # Detailed log message
        self.status_code = status_code
        self.error_code = error_code
        super().__init__(self.message)


class ValidationException(SecurityException):
    """Validation-specific security exception"""
    def __init__(self, message: str, error_code: str = "VALIDATION_ERROR"):
        super().__init__(
            message=message,
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            error_code=error_code
        )


class AuthenticationException(SecurityException):
    """Authentication/Authorization errors"""
    def __init__(self, message: str, error_code: str = "AUTH_ERROR"):
        super().__init__(
            message=message,
            status_code=status.HTTP_401_UNAUTHORIZED,
            error_code=error_code
        )


class RateLimitException(SecurityException):
    """Rate limiting exceeded"""
    def __init__(self, retry_after: int = 60):
        super().__init__(
            message="Rate limit exceeded. Please try again later.",
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            error_code="RATE_LIMIT_EXCEEDED"
        )
        self.retry_after = retry_after


# ==================== EXCEPTION HANDLERS ====================

async def security_exception_handler(request: Request, exc: SecurityException) -> JSONResponse:
    """
    Handle custom security exceptions.
    Always returns user-friendly error message without sensitive details.
    """
    # Log detailed info for debugging
    logger.warning(
        f"Security exception: {exc.error_code}",
        extra={
            "error_code": exc.error_code,
            "detail": exc.log_detail,
            "path": str(request.url.path),
            "method": request.method,
            "client_ip": request.client.host if request.client else "unknown",
        }
    )

    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.message,
            "error_code": exc.error_code,
        }
    )


async def validation_exception_handler(request: Request, exc: ValidationError) -> JSONResponse:
    """
    Handle Pydantic validation errors.
    Never expose internal validation details to client.
    """
    error_count = exc.error_count()
    logger.info(
        f"Validation error: {error_count} field(s)",
        extra={
            "path": str(request.url.path),
            "error_count": error_count,
        }
    )

    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error": "The request data is invalid. Please review your input and try again.",
            "error_code": "VALIDATION_ERROR",
            "details": f"{error_count} field validation error(s)",  # No field-level details
        }
    )


async def generic_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """
    Catch-all for unexpected exceptions.
    Never expose internal details, stack traces, or sensitive info.
    """
    # Generate unique error ID for correlation
    import uuid
    error_id = str(uuid.uuid4())

    # Log full details for debugging
    logger.error(
        f"Unhandled exception (Error ID: {error_id})",
        exc_info=exc,
        extra={
            "error_id": error_id,
            "exception_type": type(exc).__name__,
            "path": str(request.url.path),
            "method": request.method,
            "client_ip": request.client.host if request.client else "unknown",
        }
    )

    # Return generic error with correlation ID
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": "An unexpected error occurred. Please contact support.",
            "error_code": "INTERNAL_SERVER_ERROR",
            "error_id": error_id,  # For support tickets
        }
    )


# ==================== UTILITY FUNCTIONS ====================

def safe_error_detail(exception: Exception, max_length: int = 200) -> str:
    """
    Extract safe error detail from exception.
    Avoids exposing sensitive information like tokens, passwords, paths.
    """
    error_msg = str(exception)[:max_length]
    
    # Redact known sensitive patterns
    sensitive_patterns = [
        r'token.*?=.*?[\w\-]+',
        r'password.*?=.*?[\w\-]+',
        r'secret.*?=.*?[\w\-]+',
        r'key.*?=.*?[\w\-]+',
        r'Bearer\s+[\w\-\.]+',
        r'/home/\S+',  # File paths
        r'C:\\Users\\\S+',  # Windows paths
    ]
    
    import re
    for pattern in sensitive_patterns:
        error_msg = re.sub(pattern, '[REDACTED]', error_msg, flags=re.IGNORECASE)
    
    return error_msg


def redact_dict_sensitive_fields(data: dict, depth: int = 0, max_depth: int = 3) -> dict:
    """
    Recursively redact sensitive fields from dictionaries.
    Used to sanitize data before logging.
    
    Args:
        data: Dictionary to redact
        depth: Current recursion depth
        max_depth: Maximum recursion depth to prevent infinite loops
    
    Returns:
        Dictionary with sensitive fields redacted
    """
    if depth >= max_depth or not isinstance(data, dict):
        return data

    sensitive_fields = {
        'password', 'token', 'authorization', 'secret', 'key',
        'client_secret', 'access_token', 'refresh_token',
        'credit_card', 'ssn', 'pii', 'pin', 'private_key',
        'jwt', 'bearer', 'api_key', 'oauth_token'
    }

    redacted = {}
    for key, value in data.items():
        if any(sensitive in key.lower() for sensitive in sensitive_fields):
            redacted[key] = "***REDACTED***"
        elif isinstance(value, dict):
            redacted[key] = redact_dict_sensitive_fields(value, depth + 1, max_depth)
        elif isinstance(value, list) and value and isinstance(value[0], dict):
            redacted[key] = [redact_dict_sensitive_fields(item, depth + 1, max_depth) if isinstance(item, dict) else item for item in value]
        else:
            redacted[key] = value
    
    return redacted
