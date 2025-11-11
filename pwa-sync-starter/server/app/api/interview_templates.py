# server/app/api/interview_templates.py
from fastapi import APIRouter, HTTPException
from typing import List
import logging

logger = logging.getLogger("interview_templates_api")
router = APIRouter()

@router.get("/interview-templates/mobile-available")
async def get_mobile_available_templates():
    """Get all interview templates available for mobile use (Available_for_Mobile__c = true)"""
    try:
        logger.info("API request: Fetching mobile-available interview templates")
        
        from ..salesforce.interview_template_service import InterviewTemplateService
        
        service = InterviewTemplateService()
        templates = service.get_mobile_available_templates()
        
        logger.info(f"API response: Returning {len(templates)} templates")
        return {
            "success": True,
            "templates": templates,
            "count": len(templates)
        }
        
    except Exception as e:
        logger.error(f"Failed to fetch mobile-available templates: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to fetch templates: {str(e)}")


@router.get("/interview-templates/{template_version_id}/questions")
async def get_questions_for_template(template_version_id: str):
    """Get all interview questions for a specific template version"""
    try:
        logger.info(f"API request: Fetching questions for template version: {template_version_id}")
        
        from ..salesforce.interview_template_service import InterviewTemplateService
        
        if not template_version_id or template_version_id.strip() == "":
            raise HTTPException(status_code=400, detail="template_version_id is required")
        
        service = InterviewTemplateService()
        questions = service.get_questions_for_template(template_version_id)
        
        logger.info(f"API response: Returning {len(questions)} questions")
        return {
            "success": True,
            "questions": questions,
            "count": len(questions)
        }
        
    except HTTPException as he:
        raise he
    except Exception as e:
        logger.error(f"Failed to fetch questions for template version {template_version_id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to fetch questions: {str(e)}")
