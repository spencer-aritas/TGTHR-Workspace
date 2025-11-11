# server/app/api/interview_answers.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Dict
import logging

logger = logging.getLogger("interview_answers_api")
router = APIRouter()

class InterviewAnswerRequest(BaseModel):
    """Request body for submitting interview answers"""
    caseId: str
    templateVersionId: str
    answers: Dict[str, str]  # Maps question IDs to answer values

@router.post("/interview-answers")
async def save_interview_answers(request: InterviewAnswerRequest):
    """Save interview answers to Salesforce"""
    try:
        logger.info(f"API request: Saving interview answers for case {request.caseId}")
        
        from ..salesforce.interview_answer_service import InterviewAnswerService
        
        if not request.caseId or not request.templateVersionId or not request.answers:
            raise HTTPException(status_code=400, detail="caseId, templateVersionId, and answers are all required")
        
        service = InterviewAnswerService()
        result = service.save_interview_answers(
            request.caseId,
            request.templateVersionId,
            request.answers
        )
        
        logger.info(f"API response: Successfully saved interview {result['interview_id']}")
        return {
            "success": True,
            "interviewId": result['interview_id'],
            "answersCount": result['answers_count'],
            "message": result['message']
        }
        
    except HTTPException as he:
        raise he
    except Exception as e:
        logger.error(f"Failed to save interview answers: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to save interview answers: {str(e)}")
