# Security Implementation Roadmap

## Status: ✅ Quick Win Templates Ready

All four quick win implementation templates have been created and are ready to integrate:

### Created Files
1. ✅ `server/app/middleware/validation.py` - Input validation models
2. ✅ `server/app/middleware/error_handling.py` - Safe error responses
3. ✅ `server/app/utils/sanitization.py` - HTML/text sanitization  
4. ✅ `server/app/middleware/logging.py` - Audit logging middleware

---

## 🚀 Implementation Order (Priority)

### Phase 1: CRITICAL (Complete This Sprint)
**Estimated effort: 3-4 hours**

#### 1.1 Add Input Validation Middleware ⚡⚡⚡
**File to modify:** `server/app/api/sync.py`  
**Impact:** Prevents injection attacks, malformed data

```python
# At the top of sync.py
from ..middleware.validation import SyncMutationValidated, NotePayload, validate_mutation_list
from ..middleware.error_handling import ValidationException, safe_error_detail

# Replace current Mutation model and upload() function
@router.post('/sync/upload')
def upload(mutations: List[SyncMutationValidated], db: Session = Depends(get_db)):
    """
    Upload mutations with strict validation.
    Line 95 in current sync.py - REPLACE THIS ENTIRE FUNCTION
    """
    accepted = []
    serverVersion = None
    
    for m in mutations:
        try:
            if m.table == 'notes':
                # Validate note payload
                note_payload = NotePayload(**m.payload)  # Will raise ValidationError if invalid
                note_id = note_payload.id
                
                if m.op in ('insert', 'update'):
                    n = db.get(Note, note_id) or Note(id=note_id)
                    n.enrolleeId = note_payload.enrolleeId
                    n.body = note_payload.body  # Already validated
                    n.createdAt = note_payload.createdAt
                    n.updatedAt = note_payload.updatedAt
                    n.deviceId = note_payload.deviceId
                    serverVersion = get_next_version(db)
                    n.version = serverVersion
                    db.add(n)
                
                elif m.op == 'delete':
                    n = db.get(Note, note_id)
                    if n: 
                        db.delete(n)
                        serverVersion = get_next_version(db)
                
                accepted.append(m.id)
        
        except Exception as e:
            # Log validation error but continue
            import logging
            logger = logging.getLogger("sync")
            logger.warning(f"Validation error for mutation {m.id}: {safe_error_detail(e)}")
            continue  # Skip invalid mutations
    
    db.commit()
    if serverVersion is None:
        serverVersion = int((db.get(Meta, 'serverVersion') or Meta(key='serverVersion', value='0')).value)
    
    return {'acceptedIds': accepted, 'serverVersion': serverVersion}
```

**Testing:**
```bash
# Test valid mutation
curl -X POST http://localhost:8000/sync/upload \
  -H "Content-Type: application/json" \
  -d '[{
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "table": "notes",
    "op": "insert",
    "payload": {...},
    "clientTs": "2025-01-01T12:00:00Z",
    "deviceId": "device-uuid-12345678901234567890"
  }]'

# Test invalid payload (should be rejected)
curl -X POST http://localhost:8000/sync/upload \
  -H "Content-Type: application/json" \
  -d '[{
    "id": "invalid",  # Too short
    "table": "notes",
    ...
  }]'
```

---

#### 1.2 Fix Error Response Handlers ⚡⚡⚡
**Files to modify:** `server/app/api/auth.py`, `server/app/main.py`

**In `server/app/main.py` (after CORS middleware):**
```python
# Add exception handlers
from .middleware.error_handling import (
    SecurityException, security_exception_handler,
    generic_exception_handler
)

# Register handlers
app.add_exception_handler(SecurityException, security_exception_handler)
app.add_exception_handler(Exception, generic_exception_handler)
```

**In `server/app/api/auth.py` (auth.py line 33):**
```python
# ❌ REMOVE these debug prints:
print(f"Current SF_ENV: {env}")
print(f"Benefits mode - Client ID: {client_id[:20]}...")
print(f"Returning OAuth config: {config}")

# ✅ REPLACE with safe logging:
logger = logging.getLogger("auth")
logger.debug(f"OAuth config requested for env: {env}")
# NEVER log client_id, client_secret, or other credentials
```

**In `server/app/api/auth.py` (line 62-65):**
```python
# ❌ REMOVE:
print(f"Token exchange request to {token_url}")
print(f"Request data: {token_request_data}")  # EXPOSES CLIENT_SECRET!

# ✅ REPLACE with:
logger.debug(f"Token exchange initiated")  # Minimal info only
```

---

#### 1.3 Add Rate Limiting ⚡⚡
**File to modify:** `server/requirements.txt`, `server/app/main.py`

**Step 1: Update requirements.txt**
```txt
# Add this line
slowapi>=0.1.9
```

**Step 2: Update `server/app/main.py`**
```python
# Add after imports
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from fastapi.responses import JSONResponse

# Create limiter
limiter = Limiter(
    key_func=get_remote_address,
    storage_uri="memory://",  # Use Redis in production
    default_limits=["200/minute"]  # Global default
)
app.state.limiter = limiter

# Exception handler for rate limiting
@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request: Request, exc: RateLimitExceeded):
    return JSONResponse(
        status_code=429,
        content={
            "error": "Rate limit exceeded. Please try again later.",
            "error_code": "RATE_LIMIT_EXCEEDED"
        }
    )
```

**Step 3: Add decorators to sensitive endpoints**

In `server/app/api/auth.py`:
```python
@router.post("/oauth-callback")
@limiter.limit("5/minute")  # Max 5 login attempts per minute
async def handle_oauth_callback(request: Request, data: OAuthCallback):
    ...
```

In `server/app/api/sync.py`:
```python
@router.post('/sync/upload')
@limiter.limit("100/minute")  # Max 100 uploads per minute
def upload(mutations: List[SyncMutationValidated], db: Session = Depends(get_db)):
    ...
```

In `server/app/api/outreach.py`:
```python
@router.post('/quick-person-account')
@limiter.limit("20/minute")  # Max 20 person accounts per minute
async def create_quick_person_account(payload: PersonAccountPayload):
    ...
```

---

### Phase 2: HIGH (Next Sprint)
**Estimated effort: 2-3 hours**

#### 2.1 Add HTML Sanitization
**File to modify:** `server/app/api/sync.py`, `server/requirements.txt`

**Step 1: Update requirements.txt**
```txt
bleach>=6.0.0
```

**Step 2: Use sanitization in sync.py**
```python
from ..utils.sanitization import sanitize_html

# In the upload() function, when storing notes:
n.body = sanitize_html(note_payload.body)  # Sanitize before storage
```

#### 2.2 Add Audit Logging  
**File to modify:** `server/app/main.py`

```python
# After exception handlers
from .middleware.logging import setup_audit_logging

# Initialize audit logging
setup_audit_logging(app)
```

This will automatically log all requests/responses with redacted sensitive fields.

---

### Phase 3: MEDIUM (Future Quarters)
- Session timeout enforcement
- Device registration validation
- Database encryption at rest
- Audit log archival

---

## ✅ Already Done (No Changes Needed)

| Item | Status | Notes |
|------|--------|-------|
| HTTPS/TLS | ✅ | HSTS header enforced |
| Security Headers | ✅ | X-Frame-Options, X-XSS-Protection set |
| CORS Restrictions | ✅ | Limited to known origins |
| JWT Authentication | ✅ | Salesforce OAuth working |
| Environment Vars | ✅ | Pydantic settings configured |
| PersonAccount Validators | ✅ | Email, phone, name validated |

---

## 🧪 Testing Checklist

### Unit Tests to Add
```python
# server/app/tests/test_validation.py
def test_mutation_validation_valid():
    """Valid mutation should pass"""
    m = SyncMutationValidated(
        id="550e8400-e29b-41d4-a716-446655440000",
        table="notes",
        op="insert",
        payload={"id": "n1", "body": "test", ...},
        clientTs="2025-01-01T12:00:00Z",
        deviceId="device-uuid-12345678901234567890"
    )
    assert m.id  # Should not raise

def test_mutation_validation_invalid_id():
    """Short UUID should fail"""
    with pytest.raises(ValidationError):
        SyncMutationValidated(
            id="short",  # Too short
            ...
        )

def test_sanitize_html_removes_scripts():
    """XSS payload should be removed"""
    malicious = '<p>Safe</p><script>alert("xss")</script>'
    result = sanitize_html(malicious)
    assert '<script>' not in result
    assert 'Safe' in result

def test_rate_limiting():
    """Should reject requests over rate limit"""
    for i in range(6):  # 5 allowed + 1 over limit
        if i < 5:
            assert response.status_code == 200
        else:
            assert response.status_code == 429
```

### Integration Tests
```bash
# Run after implementing changes
npm run test:integration

# Or manually:
python -m pytest server/app/tests/ -v
```

---

## 📋 Deployment Checklist

- [ ] Update `server/requirements.txt` with new packages (bleach, slowapi)
- [ ] Create middleware files in correct location
- [ ] Update main.py with exception handlers and limiter
- [ ] Update each API endpoint with @limiter decorators
- [ ] Run linter: `flake8 server/app/`
- [ ] Run type checker: `mypy server/app/`
- [ ] Run tests: `pytest server/app/tests/`
- [ ] Deploy to staging first
- [ ] Monitor logs for validation errors
- [ ] Verify error messages are user-friendly (no stack traces exposed)
- [ ] Test rate limiting behavior
- [ ] Update API documentation

---

## 🔗 File Location Reference

```
server/app/
├── middleware/
│   ├── validation.py        ← NEW (Input validation)
│   ├── error_handling.py    ← NEW (Safe errors)
│   └── logging.py           ← NEW (Audit trail)
├── utils/
│   └── sanitization.py      ← NEW (HTML/text sanitization)
├── api/
│   ├── auth.py              ← MODIFY (Remove debug prints)
│   └── sync.py              ← MODIFY (Add validators)
└── main.py                  ← MODIFY (Add exception handlers, limiter)
```

---

## 📞 Support

If you have questions about:
- **Pydantic v2 validation:** See https://docs.pydantic.dev/latest/
- **FastAPI middleware:** See https://fastapi.tiangolo.com/tutorial/middleware/
- **OWASP injection prevention:** See https://owasp.org/www-project-web-security-testing-guide/

Next steps: Review this document with your team and start with Phase 1 implementation!
