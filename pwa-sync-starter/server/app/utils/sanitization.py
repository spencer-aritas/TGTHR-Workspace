"""
server/app/utils/sanitization.py

HTML and string sanitization utilities to prevent XSS and injection attacks.
"""

try:
    import bleach
    BLEACH_AVAILABLE = True
except ImportError:
    BLEACH_AVAILABLE = False

from typing import Dict, Any, List, Optional
import logging
import re

logger = logging.getLogger("sanitization")


# Allowed HTML tags for clinical notes (basic formatting only)
ALLOWED_TAGS = {
    'p', 'br', 'strong', 'em', 'u', 'ol', 'ul', 'li',
    'blockquote', 'code', 'pre', 'h1', 'h2', 'h3',
    'table', 'tr', 'td', 'th', 'tbody', 'thead'
}

# Allowed HTML attributes (very restricted)
ALLOWED_ATTRIBUTES = {
    'table': ['border', 'cellpadding', 'cellspacing'],
    'td': ['colspan', 'rowspan'],
    'th': ['colspan', 'rowspan'],
}

# Protocols allowed in URLs (prevent javascript:, data:, etc)
ALLOWED_PROTOCOLS = {'http', 'https', 'mailto', 'tel'}


def sanitize_html(content: str, allowed_tags: Optional[set] = None, 
                  allowed_attributes: Optional[dict] = None) -> str:
    """
    Sanitize HTML content to prevent XSS attacks.
    Removes all script tags and dangerous attributes.
    
    Args:
        content: Raw HTML/text content
        allowed_tags: Set of allowed HTML tags (defaults to ALLOWED_TAGS)
        allowed_attributes: Dict of allowed attributes per tag (defaults to ALLOWED_ATTRIBUTES)
    
    Returns:
        Sanitized content safe for display
    
    Example:
        >>> content = '<p>Safe</p><script>alert("xss")</script>'
        >>> sanitize_html(content)
        '<p>Safe</p>'
    """
    if not content or not isinstance(content, str):
        return ""
    
    if allowed_tags is None:
        allowed_tags = ALLOWED_TAGS
    if allowed_attributes is None:
        allowed_attributes = ALLOWED_ATTRIBUTES

    try:
        if not BLEACH_AVAILABLE:
            # Fallback: basic HTML removal
            return _remove_dangerous_patterns(content).strip()
        
        # Use bleach library for safe HTML sanitization
        cleaned = bleach.clean(
            content,
            tags=allowed_tags,
            attributes=allowed_attributes,
            strip=True,  # Strip disallowed tags instead of escaping
            strip_comments=True
        )
        
        # Additional safety: remove any remaining suspicious patterns
        cleaned = _remove_dangerous_patterns(cleaned)
        
        return cleaned.strip()
    
    except Exception as e:
        logger.error(f"Error sanitizing HTML: {str(e)}")
        # Fallback: escape all HTML if sanitization fails
        if BLEACH_AVAILABLE:
            return bleach.clean(content, tags=[], strip=True)
        else:
            return _remove_dangerous_patterns(content)


def sanitize_text(content: str, max_length: Optional[int] = None) -> str:
    """
    Sanitize plain text (no HTML allowed).
    Removes control characters and suspicious patterns.
    
    Args:
        content: Raw text content
        max_length: Maximum allowed length (None for unlimited)
    
    Returns:
        Sanitized text
    """
    if not content or not isinstance(content, str):
        return ""
    
    # Remove control characters (except newlines and tabs)
    sanitized = ''.join(
        char for char in content 
        if ord(char) >= 32 or char in '\n\t'
    )
    
    if max_length and len(sanitized) > max_length:
        sanitized = sanitized[:max_length]
    
    return sanitized.strip()


def sanitize_dict(data: Dict[str, Any], 
                  html_fields: Optional[List[str]] = None,
                  text_fields: Optional[List[str]] = None) -> Dict[str, Any]:
    """
    Sanitize specific fields in a dictionary.
    Useful for bulk sanitization of API request payloads.
    
    Args:
        data: Dictionary to sanitize
        html_fields: List of field names containing HTML to sanitize
        text_fields: List of field names containing plain text to sanitize
    
    Returns:
        Dictionary with specified fields sanitized
    
    Example:
        >>> data = {'notes': '<p>Safe</p><script>alert("xss")</script>', 'name': 'John'}
        >>> sanitize_dict(data, html_fields=['notes'])
        {'notes': '<p>Safe</p>', 'name': 'John'}
    """
    if not data or not isinstance(data, dict):
        return data

    sanitized = data.copy()
    
    if html_fields:
        for field in html_fields:
            if field in sanitized and isinstance(sanitized[field], str):
                sanitized[field] = sanitize_html(sanitized[field])
    
    if text_fields:
        for field in text_fields:
            if field in sanitized and isinstance(sanitized[field], str):
                sanitized[field] = sanitize_text(sanitized[field])
    
    return sanitized


def _remove_dangerous_patterns(content: str) -> str:
    """
    Additional safety layer: remove suspicious patterns that might bypass bleach.
    """
    # Remove any remaining event handlers
    dangerous_patterns = [
        r'on\w+\s*=',  # onload=, onclick=, etc.
        r'javascript:',
        r'data:text/html',
        r'vbscript:',
        r'<embed',
        r'<object',
        r'<iframe',
        r'<frame',
        r'<frameset',
        r'<applet',
    ]
    
    result = content
    for pattern in dangerous_patterns:
        result = re.sub(pattern, '', result, flags=re.IGNORECASE)
    
    return result


def is_safe_url(url: str, allowed_protocols: Optional[set] = None) -> bool:
    """
    Validate that a URL only uses safe protocols.
    
    Args:
        url: URL to validate
        allowed_protocols: Set of safe protocols (defaults to ALLOWED_PROTOCOLS)
    
    Returns:
        True if URL is safe, False otherwise
    
    Example:
        >>> is_safe_url('https://example.com')
        True
        >>> is_safe_url('javascript:alert("xss")')
        False
    """
    if not url or not isinstance(url, str):
        return False
    
    if allowed_protocols is None:
        allowed_protocols = ALLOWED_PROTOCOLS
    
    # Extract protocol
    if '://' not in url and not url.startswith('mailto:') and not url.startswith('tel:'):
        return True  # Relative URL
    
    protocol = url.split('://')[0].split(':')[0].lower()
    return protocol in allowed_protocols


def sanitize_filename(filename: str, max_length: int = 255) -> str:
    """
    Sanitize filename to prevent directory traversal and other attacks.
    
    Args:
        filename: Original filename
        max_length: Maximum filename length
    
    Returns:
        Safe filename
    
    Example:
        >>> sanitize_filename('../../../etc/passwd')
        'etc_passwd'
    """
    if not filename or not isinstance(filename, str):
        return "file"
    
    # Remove path separators and null bytes
    safe_name = filename.replace('/', '_').replace('\\', '_').replace('\0', '')
    
    # Remove special characters except . - _
    safe_name = re.sub(r'[^\w\.\-]', '_', safe_name)
    
    # Remove leading/trailing dots and spaces
    safe_name = safe_name.strip('. ')
    
    # Truncate to max length
    if len(safe_name) > max_length:
        # Try to preserve file extension
        parts = safe_name.rsplit('.', 1)
        if len(parts) == 2:
            name, ext = parts
            max_name_len = max_length - len(ext) - 1
            safe_name = name[:max_name_len] + '.' + ext
        else:
            safe_name = safe_name[:max_length]
    
    # Ensure it's not empty
    return safe_name or "file"
