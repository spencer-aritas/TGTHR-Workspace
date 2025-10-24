# server/app/salesforce/interaction_summary_service.py
import logging
from typing import Dict, Any
from datetime import datetime
from .sf_client import SalesforceClient

logger = logging.getLogger("interaction_summary_service")

class InteractionSummaryService:
    """Service for managing InteractionSummary records"""
    
    def __init__(self):
        self.sf_client = SalesforceClient()
    
    def create_interaction_summary(self, data: Dict[str, Any]) -> str:
        """Create an InteractionSummary record in Salesforce"""
        try:
            logger.info(f"Creating interaction summary for case: {data.get('RelatedRecordId')}")
            
            # Combine date and times into proper datetime format
            interaction_date = data['InteractionDate']
            start_time = data['StartTime']
            end_time = data['EndTime']
            
            # Create the interaction summary record
            interaction_data = {
                'Name': f"Interaction - {interaction_date} {start_time}-{end_time}",
                'RelatedRecordId__c': data['RelatedRecordId'],
                'InteractionDate__c': interaction_date,
                'StartTime__c': start_time,
                'EndTime__c': end_time,
                'Notes__c': data['Notes'],
                'CreatedBy__c': data.get('CreatedBy'),
                'CreatedByEmail__c': data.get('CreatedByEmail')
            }
            
            result = self.sf_client.create('InteractionSummary__c', interaction_data)
            
            if result.get('success'):
                logger.info(f"Successfully created interaction summary: {result['id']}")
                return result['id']
            else:
                raise Exception(f"Salesforce creation failed: {result}")
                
        except Exception as e:
            logger.error(f"Failed to create interaction summary: {e}")
            raise