# server/app/api/pending_signatures.py
"""API endpoints for mobile co-signing (CM / PS / Manager on Interview__c)."""
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel
from typing import Optional
import logging

logger = logging.getLogger("pending_signatures_api")
router = APIRouter(tags=["pending-signatures"])


@router.get("/pending-signatures")
async def get_pending_signatures(userId: str = Query(..., description="Salesforce User Id")):
    """Return Interview__c records awaiting the current user's signature."""
    try:
        logger.info(f"Fetching pending signatures for user {userId}")
        from ..salesforce.signing_service import SigningService

        service = SigningService()
        items = service.get_pending_signatures(userId)
        return {"items": items, "count": len(items)}
    except Exception as e:
        logger.error(f"Failed to fetch pending signatures: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


class CosignRequest(BaseModel):
    userId: str
    role: str  # CaseManager | PeerSupport | Manager
    signatureDataUrl: Optional[str] = None


@router.post("/pending-signatures/{interviewId}/sign")
async def cosign_interview(interviewId: str, request: CosignRequest):
    """Complete a co-signature on an Interview__c from the PWA."""
    if request.role not in ("CaseManager", "PeerSupport", "Manager"):
        raise HTTPException(status_code=400, detail="role must be CaseManager, PeerSupport, or Manager")
    try:
        logger.info(f"Co-sign request: {interviewId} as {request.role} by {request.userId}")
        from ..salesforce.signing_service import SigningService

        service = SigningService()
        result = service.cosign_interview(
            interviewId, request.userId, request.role, request.signatureDataUrl
        )
        return result
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"Co-sign failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
