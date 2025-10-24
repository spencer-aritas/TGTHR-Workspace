from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
import logging
from ..salesforce.interaction_summary_service import InteractionSummaryService

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

@router.post("/interaction-summary")
async def create_interaction_summary(request: InteractionSummaryRequest):
    """Create an interaction summary record in Salesforce"""
    try:
        logger.info(f"Received interaction summary request: {request.dict()}")
        service = InteractionSummaryService()
        interaction_id = service.create_interaction_summary(request.dict())
        return {"id": interaction_id, "success": True}
        
    except Exception as e:
        logger.error(f"Failed to create interaction summary: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to create interaction summary: {str(e)}")