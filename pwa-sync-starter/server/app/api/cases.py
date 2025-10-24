from fastapi import APIRouter, HTTPException, Query
from typing import List, Dict, Any
import logging
from ..salesforce.case_service import CaseService

logger = logging.getLogger("cases_api")
router = APIRouter()

@router.get("/cases/my-cases")
async def get_my_cases(userId: str = Query(...)):
    """Get active cases for the current user"""
    try:
        case_service = CaseService()
        cases = case_service.get_active_cases_for_user(userId)
        return cases
        
    except Exception as e:
        logger.error(f"Failed to fetch cases: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch cases")