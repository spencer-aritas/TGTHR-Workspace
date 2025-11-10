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
