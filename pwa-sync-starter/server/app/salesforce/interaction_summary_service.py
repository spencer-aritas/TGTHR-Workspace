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
            
            # Create the interaction summary record using the existing sf_client method
            from .sf_client import call_interaction_summary_service
            
            # Use the existing interaction summary creation method
            interaction_id = call_interaction_summary_service(
                account_id=data['RelatedRecordId'],
                notes=data['Notes'],
                uuid=f"interaction_{datetime.now().isoformat()}",
                created_by_user_id=data.get('CreatedBy')
            )
            
            logger.info(f"Successfully created interaction summary: {interaction_id}")
            return interaction_id
                
        except Exception as e:
            logger.error(f"Failed to create interaction summary: {e}")
            raise