from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel
from typing import Optional, List
import logging

logger = logging.getLogger("interaction_summary_api")
router = APIRouter()

class InteractionSummaryRequest(BaseModel):
    RelatedRecordId: str
    InteractionDate: str
    StartTime: str
    EndTime: str
    Notes: str
    CreatedBy: str
    CreatedByEmail: str

class InteractionSummaryResponse(BaseModel):
    Id: str
    RelatedRecordId: str
    InteractionDate: str
    StartTime: Optional[str] = None
    EndTime: Optional[str] = None
    Notes: str
    CreatedByName: Optional[str] = None
    CreatedDate: str

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