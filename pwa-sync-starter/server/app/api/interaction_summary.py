from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel
from typing import Optional, List
import logging

logger = logging.getLogger("interaction_summary_api")
router = APIRouter()

class InteractionSummaryRequest(BaseModel):
    RelatedRecordId: str
    AccountId: Optional[str] = None
    InteractionDate: str
    StartTime: str
    EndTime: str
    Notes: str
    NoteType: Optional[str] = None
    SSRSAssessmentId: Optional[str] = None
    CreatedBy: str
    CreatedByEmail: str

class InteractionTimelineRow(BaseModel):
    Id: str
    Name: Optional[str] = None
    RelatedRecordId: Optional[str] = None
    AccountId: Optional[str] = None
    InteractionPurpose: Optional[str] = None
    Status: Optional[str] = None
    InteractionDate: Optional[str] = None
    StartTime: Optional[str] = None
    EndTime: Optional[str] = None
    Notes: Optional[str] = None
    NoteType: Optional[str] = None
    SSRSAssessmentId: Optional[str] = None
    CreatedByName: Optional[str] = None
    CreatedDate: Optional[str] = None
    LastModifiedDate: Optional[str] = None
    InterviewId: Optional[str] = None
    ActionRequired: Optional[str] = None
    ActionAssignedTo: Optional[str] = None
    RequiresManagerApproval: Optional[bool] = None
    ManagerSigned: Optional[bool] = None
    ManagerRejected: Optional[bool] = None
    ManagerApprover: Optional[str] = None

# Keep old name as alias for backward compatibility
InteractionSummaryResponse = InteractionTimelineRow

@router.get("/interaction-summary/test")
async def test_interaction_summary():
    """Test endpoint to verify router is working"""
    return {"status": "ok", "message": "Interaction summary router is working"}

@router.get("/interaction-summary/by-case/{caseId}")
async def get_interactions_by_case(caseId: str, maxRows: int = Query(50, ge=1, le=500)):
    """Get all interaction summaries for a specific case"""
    try:
        logger.info(f"API request: Fetching interactions for case: {caseId} with maxRows: {maxRows}")
        
        from ..salesforce.interaction_summary_service import InteractionSummaryService
        
        service = InteractionSummaryService()
        interactions = service.get_interactions_by_record(caseId, maxRows)
        
        logger.info(f"API response: Returning {len(interactions)} interactions for case {caseId}")
        return {"interactions": interactions, "count": len(interactions)}
        
    except Exception as e:
        logger.error(f"Failed to fetch interactions for case {caseId}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to fetch interactions: {str(e)}")

@router.post("/interaction-summary")
async def create_interaction_summary(request: InteractionSummaryRequest):
    """Create an interaction summary record in Salesforce"""
    try:
        logger.info(f"Received interaction summary request: {request.dict()}")
        
        # Import here to avoid startup issues
        from ..salesforce.interaction_summary_service import InteractionSummaryService
        
        service = InteractionSummaryService()
        interaction_id = service.create_interaction_summary(request.dict())
        return {"id": interaction_id, "success": True}
        
    except Exception as e:
        logger.error(f"Failed to create interaction summary: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to create interaction summary: {str(e)}")


@router.get("/interaction-summary/{interactionId}")
async def get_interaction_detail(interactionId: str, currentUserId: Optional[str] = Query(None)):
    """Get a single interaction summary with full detail and related records"""
    try:
        logger.info(f"API request: Fetching interaction detail for: {interactionId}")

        from ..salesforce.interaction_summary_service import InteractionSummaryService

        service = InteractionSummaryService()
        detail = service.get_interaction_detail(interactionId, current_user_id=currentUserId)

        if detail is None:
            raise HTTPException(status_code=404, detail="Interaction not found")

        return detail

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to fetch interaction detail {interactionId}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to fetch interaction detail: {str(e)}")


class ManagerApproveRequest(BaseModel):
    userId: str
    signatureDataUrl: Optional[str] = None


@router.post("/interaction-summary/{interactionId}/manager-approve")
async def manager_approve_interaction(interactionId: str, request: ManagerApproveRequest):
    """Manager approves/signs an interaction summary from the PWA"""
    try:
        logger.info(f"Manager approve request for interaction {interactionId} by user {request.userId}")

        from ..salesforce.interaction_summary_service import InteractionSummaryService

        service = InteractionSummaryService()
        result = service.manager_approve(interactionId, request.userId, request.signatureDataUrl)
        return result

    except Exception as e:
        logger.error(f"Manager approve failed for {interactionId}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Manager approve failed: {str(e)}")