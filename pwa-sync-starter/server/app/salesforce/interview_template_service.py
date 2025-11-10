# server/app/salesforce/interview_template_service.py
import logging
from typing import Dict, Any, List
from .sf_client import SalesforceClient

logger = logging.getLogger("interview_template_service")

class InterviewTemplateService:
    """Service for managing Interview Templates"""
    
    def __init__(self):
        self.sf_client = SalesforceClient()
    
    def get_mobile_available_templates(self) -> List[Dict[str, Any]]:
        """Fetch interview templates marked as Available_for_Mobile__c = true"""
        try:
            logger.info("Fetching mobile-available interview templates")
            
            # Call the Apex REST endpoint
            result = self.sf_client.call_apex_rest(
                'InterviewTemplateController/getMobileAvailableTemplates',
                {}
            )
            
            logger.info(f"Found {len(result) if isinstance(result, list) else 0} templates")
            return result if isinstance(result, list) else []
            
        except Exception as e:
            logger.error(f"Failed to fetch mobile-available templates: {e}", exc_info=True)
            # Return empty list instead of raising to prevent breaking the UI
            return []
