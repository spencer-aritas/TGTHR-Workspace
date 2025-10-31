from fastapi import APIRouter, HTTPException, Header
from typing import Optional

router = APIRouter(prefix="/api/auth", tags=["auth"])

@router.get("/check")
async def check_auth(authorization: Optional[str] = Header(None)):
    """Check if the current JWT token is valid"""
    if not authorization:
        raise HTTPException(status_code=401, detail="No authorization token provided")
        
    try:
        # Just verify it's in the right format for now
        if not authorization.startswith('Bearer '):
            raise HTTPException(status_code=401, detail="Invalid token format")
            
        # TODO: Add actual JWT verification here
        return {"status": "ok"}
        
    except Exception as e:
        raise HTTPException(status_code=401, detail=str(e))