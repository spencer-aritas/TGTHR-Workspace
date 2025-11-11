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
            
            # Query InterviewTemplateVersion__c records where parent Available_for_Mobile__c = true and Status = Active
            soql = """
                SELECT Id, Name, InterviewTemplate__c, InterviewTemplate__r.Name,
                       InterviewTemplate__r.Category__c, Status__c, Variant__c,
                       Effective_From__c, Effective_To__c
                FROM InterviewTemplateVersion__c
                WHERE InterviewTemplate__r.Active__c = true
                AND InterviewTemplate__r.Available_for_Mobile__c = true
                AND Status__c = 'Active'
                ORDER BY InterviewTemplate__r.Name, Variant__c, Name
            """
            
            result = self.sf_client.query(soql)
            
            if result and 'records' in result:
                templates = []
                for record in result['records']:
                    template_rel = record.get('InterviewTemplate__r', {})
                    templates.append({
                        'templateId': record.get('InterviewTemplate__c'),
                        'templateVersionId': record.get('Id'),
                        'templateName': template_rel.get('Name'),
                        'category': template_rel.get('Category__c'),
                        'versionName': record.get('Name'),
                        'variant': record.get('Variant__c'),
                        'status': record.get('Status__c'),
                        'effectiveFrom': record.get('Effective_From__c'),
                        'effectiveTo': record.get('Effective_To__c')
                    })
                logger.info(f"Found {len(templates)} mobile-available templates")
                return templates
            
            logger.warning("No mobile-available templates found")
            return []
            
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
