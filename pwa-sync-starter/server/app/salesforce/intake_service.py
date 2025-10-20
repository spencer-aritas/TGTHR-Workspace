# server/app/salesforce/intake_service.py
import logging
from typing import Dict, Any, List
from .sf_client import SalesforceClient

logger = logging.getLogger("intake_service")

class IntakeService:
    """Service for processing comprehensive new client intakes"""
    
    def __init__(self):
        self.sf_client = SalesforceClient()
    
    def process_full_intake(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Process complete new client intake workflow"""
        try:
            logger.info(f"Processing full intake for person: {payload['personUuid']}")
            
            # Call the existing ProgramEnrollmentService.ingestEncounter with enhanced data
            encounter_data = {
                "encounterUuid": payload['encounterUuid'],
                "personUuid": payload['personUuid'],
                "firstName": payload['firstName'],
                "lastName": payload['lastName'],
                "startUtc": payload['startUtc'],
                "endUtc": payload['endUtc'],
                "pos": payload['pos'],
                "isCrisis": payload['isCrisis'],
                "notes": payload['notes'],
                "email": payload.get('email'),
                "phone": payload.get('phone'),
                "birthdate": payload.get('birthdate'),
                "deviceId": payload['deviceId'],
                "createdBy": payload['createdBy'],
                "createdByEmail": payload['createdByEmail']
            }
            
            # Make REST call to enhanced ProgramEnrollmentService
            response = self.sf_client.call_apex_rest(
                'ProgramEnrollmentService',
                encounter_data
            )
            
            if response.get('success'):
                logger.info(f"Successfully processed intake: {response}")
                return {
                    'personAccountId': response.get('accountId'),
                    'programEnrollmentId': response.get('enrollmentId'),
                    'benefitAssignmentIds': response.get('benefitAssignmentIds', []),
                    'interactionSummaryId': response.get('interactionSummaryId'),
                    'taskId': response.get('taskId')
                }
            else:
                raise Exception(f"Salesforce processing failed: {response}")
                
        except Exception as e:
            logger.error(f"Failed to process full intake: {e}")
            raise

def process_full_intake(payload: Dict[str, Any]) -> Dict[str, Any]:
    """Standalone function for processing full intake"""
    service = IntakeService()
    return service.process_full_intake(payload)