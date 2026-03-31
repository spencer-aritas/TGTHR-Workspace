# server/app/api/pending_signatures.py
"""API endpoints for mobile co-signing (Interview__c + InteractionSummary)."""
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel
from typing import Optional, Literal
import logging

logger = logging.getLogger("pending_signatures_api")
router = APIRouter(tags=["pending-signatures"])


@router.get("/pending-signatures")
async def get_pending_signatures(userId: str = Query(..., description="Salesforce User Id")):
    """Return Interview__c and InteractionSummary records awaiting the current user's signature."""
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
    recordType: Literal['Interview', 'Interaction'] = 'Interview'
    signatureDataUrl: Optional[str] = None


@router.post("/pending-signatures/{recordId}/sign")
async def cosign_record(recordId: str, request: CosignRequest):
    """Complete a co-signature on an Interview__c or InteractionSummary from the PWA."""
    if request.role not in ("CaseManager", "PeerSupport", "Manager"):
        raise HTTPException(status_code=400, detail="role must be CaseManager, PeerSupport, or Manager")
    try:
        logger.info(f"Co-sign request: {recordId} ({request.recordType}) as {request.role} by {request.userId}")
        from ..salesforce.signing_service import SigningService

        service = SigningService()

        if request.recordType == "Interaction":
            # InteractionSummary — manager-only approval
            if request.role != "Manager":
                raise HTTPException(
                    status_code=400,
                    detail="Only Manager role is supported for InteractionSummary approval",
                )
            result = service.approve_interaction_summary(recordId, request.userId)
        else:
            # Interview__c — CM/PS/Manager co-sign
            result = service.cosign_interview(
                recordId, request.userId, request.role, request.signatureDataUrl
            )
        return result
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"Co-sign failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
