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
            
            # First, log what we're querying
            logger.debug("Query criteria: Active__c=true, Available_for_Mobile__c=true, Status__c='Active'")
            
            # Start with strict filters
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
            
            logger.debug(f"Executing SOQL: {soql}")
            result = self.sf_client.query(soql)
            
            logger.debug(f"Query result: {result}")
            
            if result and 'records' in result:
                templates = []
                for record in result['records']:
                    template_rel = record.get('InterviewTemplate__r', {})
                    template_data = {
                        'templateId': record.get('InterviewTemplate__c'),
                        'templateVersionId': record.get('Id'),
                        'templateName': template_rel.get('Name'),
                        'category': template_rel.get('Category__c'),
                        'versionName': record.get('Name'),
                        'variant': record.get('Variant__c'),
                        'status': record.get('Status__c'),
                        'effectiveFrom': record.get('Effective_From__c'),
                        'effectiveTo': record.get('Effective_To__c')
                    }
                    logger.debug(f"Template: {template_data}")
                    templates.append(template_data)
                logger.info(f"Found {len(templates)} mobile-available templates with strict filters")
                
                # If we found some templates, return them
                if templates:
                    return templates
            
            # If strict filter found nothing, try a more lenient query to help debug
            logger.warning("No templates found with strict filters. Trying lenient query for debugging...")
            
            lenient_soql = """
                SELECT Id, Name, InterviewTemplate__c, InterviewTemplate__r.Name,
                       InterviewTemplate__r.Category__c, InterviewTemplate__r.Active__c,
                       InterviewTemplate__r.Available_for_Mobile__c, Status__c, Variant__c
                FROM InterviewTemplateVersion__c
                ORDER BY InterviewTemplate__r.Name, Variant__c, Name
                LIMIT 100
            """
            
            logger.debug(f"Executing lenient SOQL: {lenient_soql}")
            lenient_result = self.sf_client.query(lenient_soql)
            logger.debug(f"Lenient result: {lenient_result}")
            
            if lenient_result and 'records' in lenient_result:
                logger.warning(f"Found {len(lenient_result['records'])} total templates, but none match strict criteria:")
                for record in lenient_result['records']:
                    template_rel = record.get('InterviewTemplate__r', {})
                    logger.warning(f"  - {template_rel.get('Name')} / {record.get('Name')}: "
                                 f"Active={template_rel.get('Active__c')}, "
                                 f"Mobile={template_rel.get('Available_for_Mobile__c')}, "
                                 f"Status={record.get('Status__c')}")
            
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
            # Field names from Salesforce schema (confirmed from InterviewTemplateController.cls):
            # Label__c (not QuestionText__c), Response_Type__c (not QuestionType__c), 
            # Required__c (not IsRequired__c), Order__c (not DisplayOrder__c)
            soql = f"""
                SELECT Id, Name, Label__c, API_Name__c, Response_Type__c, Required__c,
                       Maps_To__c, Help_Text__c, Order__c, Section__c, Sensitive__c, 
                       Score_Weight__c, Picklist_Values__c
                FROM InterviewQuestion__c
                WHERE InterviewTemplateVersion__c = '{template_version_id}'
                ORDER BY Order__c ASC, Name ASC
            """
            
            logger.debug(f"Executing SOQL: {soql}")
            result = self.sf_client.query(soql)
            
            logger.debug(f"Query result for questions: {result}")
            
            if result and 'records' in result:
                questions = []
                for record in result['records']:
                    question_data = {
                        'Id': record.get('Id'),
                        'Name': record.get('Name'),
                        'QuestionText': record.get('Label__c'),  # Map Label__c to QuestionText for frontend
                        'QuestionType': record.get('Response_Type__c'),  # Map Response_Type__c to QuestionType
                        'IsRequired': record.get('Required__c', False),  # Map Required__c to IsRequired
                        'ApiName': record.get('API_Name__c'),
                        'MapsTo': record.get('Maps_To__c'),
                        'HelpText': record.get('Help_Text__c'),
                        'Section': record.get('Section__c'),
                        'Sensitive': record.get('Sensitive__c', False),
                        'ScoreWeight': record.get('Score_Weight__c'),
                        'Options': record.get('Picklist_Values__c'),  # Map Picklist_Values__c to Options
                        'DisplayOrder': record.get('Order__c')  # Map Order__c to DisplayOrder
                    }
                    logger.debug(f"Question: {question_data}")
                    questions.append(question_data)
                logger.info(f"Found {len(questions)} questions for template version {template_version_id}")
                return questions
            
            logger.warning(f"No questions found for template version {template_version_id}")
            return []
            
        except Exception as e:
            logger.error(f"Failed to fetch questions for template version {template_version_id}: {e}", exc_info=True)
            # Return empty list instead of raising
            return []
