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

    def get_questions_for_template(self, template_version_id: str) -> List[Dict[str, Any]]:
        """Fetch interview questions for a specific template version"""
        try:
            logger.info(f"Fetching interview questions for template version: {template_version_id}")
            
            # Query InterviewQuestion__c records where InterviewTemplateVersion__c matches
            soql = f"""
                SELECT Id, Name, QuestionText__c, QuestionType__c, IsRequired__c, 
                       FieldReference__c, Options__c, DisplayOrder__c
                FROM InterviewQuestion__c
                WHERE InterviewTemplateVersion__c = '{template_version_id}'
                ORDER BY DisplayOrder__c ASC, Name ASC
            """
            
            result = self.sf_client.query(soql)
            
            if result and 'records' in result:
                questions = []
                for record in result['records']:
                    questions.append({
                        'Id': record.get('Id'),
                        'Name': record.get('Name'),
                        'QuestionText': record.get('QuestionText__c'),
                        'QuestionType': record.get('QuestionType__c'),
                        'IsRequired': record.get('IsRequired__c', False),
                        'FieldReference': record.get('FieldReference__c'),
                        'Options': record.get('Options__c'),
                        'DisplayOrder': record.get('DisplayOrder__c')
                    })
                logger.info(f"Found {len(questions)} questions for template version {template_version_id}")
                return questions
            
            logger.warning(f"No questions found for template version {template_version_id}")
            return []
            
        except Exception as e:
            logger.error(f"Failed to fetch questions for template version {template_version_id}: {e}", exc_info=True)
            # Return empty list instead of raising
            return []
