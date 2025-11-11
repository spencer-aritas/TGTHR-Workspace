# server/app/salesforce/interview_answer_service.py
import logging
from typing import Dict, Any, List
from .sf_client import _sf, _api

logger = logging.getLogger("interview_answer_service")

class InterviewAnswerService:
    """Service for managing Interview Answers"""
    
    def save_interview_answers(self, case_id: str, template_version_id: str, answers: Dict[str, str]) -> Dict[str, Any]:
        """
        Save interview answers to Salesforce
        
        Args:
            case_id: ID of the Case
            template_version_id: ID of the InterviewTemplateVersion
            answers: Dictionary mapping question IDs to answer values
        
        Returns:
            Dictionary with success status and interview/answer record IDs
        """
        try:
            logger.info(f"Saving interview answers for case {case_id} and template {template_version_id}")
            
            if not case_id or not template_version_id or not answers:
                raise ValueError("case_id, template_version_id, and answers are all required")
            
            # First, create an Interview__c header record
            interview_data = {
                'Name': f'Interview - {template_version_id}',
                'Case__c': case_id,
                'InterviewTemplateVersion__c': template_version_id,
                'Status__c': 'Completed'
            }
            
            logger.debug(f"Creating Interview header: {interview_data}")
            interview_result = _sf(_api("/sobjects/Interview__c/"), method="POST", json=interview_data)
            
            if not interview_result or 'id' not in interview_result:
                raise Exception(f"Failed to create Interview record: {interview_result}")
            
            interview_id = interview_result['id']
            logger.info(f"Created Interview record: {interview_id}")
            
            # Now create InterviewAnswer__c records for each answer
            answer_count = 0
            for question_id, answer_value in answers.items():
                try:
                    answer_record = {
                        'Name': f'Answer - {question_id}',
                        'Interview__c': interview_id,
                        'InterviewQuestion__c': question_id,
                        'Answer__c': answer_value
                    }
                    
                    logger.debug(f"Creating InterviewAnswer: {answer_record}")
                    answer_result = _sf(_api("/sobjects/InterviewAnswer__c/"), method="POST", json=answer_record)
                    
                    if answer_result and 'id' in answer_result:
                        answer_count += 1
                    else:
                        logger.warning(f"Failed to create answer for question {question_id}: {answer_result}")
                        
                except Exception as e:
                    logger.warning(f"Failed to create answer for question {question_id}: {e}", exc_info=True)
                    # Continue with other answers even if one fails
                    continue
            
            logger.info(f"Created {answer_count} InterviewAnswer records")
            
            return {
                'success': True,
                'interview_id': interview_id,
                'answers_count': answer_count,
                'message': f'Successfully saved interview with {answer_count} answers'
            }
            
        except Exception as e:
            logger.error(f"Failed to save interview answers: {e}", exc_info=True)
            raise
