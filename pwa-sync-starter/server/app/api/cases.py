from fastapi import APIRouter, HTTPException, Query
import logging
from ..salesforce.case_service import CaseService
from ..salesforce.audit_log_service import audit_logger

logger = logging.getLogger("cases_api")
router = APIRouter()

@router.get("/cases/my-cases")
async def get_my_cases(userId: str = Query(...)):
    """Get active cases for the current user"""
    try:
        case_service = CaseService()
        cases = case_service.get_active_cases_for_user(userId)
        for case in cases:
            entity_id = case.get('AccountId') or (case.get('Account') or {}).get('Id')
            if not entity_id:
                continue
            details = f"Case list view: Case {case.get('CaseNumber')} ({case.get('Status')})"
            audit_logger.log_action(
                action_type="VIEW_PARTICIPANT_CASE",
                entity_id=entity_id,
                details=details,
                user_id=userId,
                event_type="ACCESS",
            )
        return cases
        
    except Exception as e:
        logger.error(f"Failed to fetch cases for user {userId}: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch cases")
