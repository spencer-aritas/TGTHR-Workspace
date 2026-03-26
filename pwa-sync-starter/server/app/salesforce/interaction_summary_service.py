# server/app/salesforce/interaction_summary_service.py
import logging
from typing import Dict, Any, List
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

            # Create the interaction summary record using the existing sf_client method
            from .sf_client import call_interaction_summary_service

            # Use the existing interaction summary creation method
            interaction_id = call_interaction_summary_service(
                record_id=data['RelatedRecordId'],
                account_id=data.get('AccountId'),
                notes=data['Notes'],
                interaction_date=data['InteractionDate'],
                start_time=data.get('StartTime'),
                end_time=data.get('EndTime'),
                interaction_purpose=self._normalize_note_type(data.get('NoteType')),
                uuid=f"interaction_{datetime.now().isoformat()}",
                created_by_user_id=data.get('CreatedBy') or ''
            )

            ssrs_assessment_id = data.get('SSRSAssessmentId')
            if ssrs_assessment_id:
                from .assessment_service import AssessmentServiceClient

                AssessmentServiceClient().link_assessment_to_interaction(
                    ssrs_assessment_id,
                    interaction_id
                )
            
            logger.info(f"Successfully created interaction summary: {interaction_id}")
            return interaction_id
                
        except Exception as e:
            logger.error(f"Failed to create interaction summary: {e}")
            raise
    
    def get_interactions_by_record(self, record_id: str, max_rows: int = 50) -> List[Dict[str, Any]]:
        """Fetch interaction summaries for a specific record (Case, Account, etc.)"""
        try:
            logger.info(f"Fetching interactions for record: {record_id} (type: {type(record_id).__name__})")
            
            # Query InteractionSummary records related to this case/account
            # Use standard fields: RelatedRecordId (case), Date_of_Interaction__c (date), MeetingNotes (notes)
            query = """
            SELECT Id, Name, RelatedRecordId, Date_of_Interaction__c, 
                     AccountId, InteractionPurpose, Start_Time__c, End_Time__c, MeetingNotes,
                     CreatedDate, 
                   CreatedBy.Name
            FROM InteractionSummary
            WHERE RelatedRecordId = :recordId
            ORDER BY Date_of_Interaction__c DESC, CreatedDate DESC
            LIMIT :maxRows
            """
            
            logger.debug(f"Query: {query}")
            logger.debug(f"Parameters: recordId={record_id}, maxRows={max_rows}")
            
            result = self.sf_client.query(query, {
                "recordId": record_id,
                "maxRows": max_rows
            })
            
            logger.debug(f"Query result: {result}")
            
            interactions = []
            for record in result.get('records', []):
                interaction = {
                    'Id': record.get('Id'),
                    'RelatedRecordId': record.get('RelatedRecordId'),
                    'AccountId': record.get('AccountId'),
                    'InteractionDate': record.get('Date_of_Interaction__c'),
                    'StartTime': record.get('Start_Time__c'),
                    'EndTime': record.get('End_Time__c'),
                    'Notes': record.get('MeetingNotes'),
                    'NoteType': record.get('InteractionPurpose'),
                    'CreatedByName': record.get('CreatedBy', {}).get('Name') if record.get('CreatedBy') else 'Unknown',
                    'CreatedDate': record.get('CreatedDate')
                }
                logger.debug(f"Mapped interaction: {interaction}")
                interactions.append(interaction)
            
            logger.info(f"Found {len(interactions)} interactions for record {record_id}")
            return interactions
                
        except Exception as e:
            logger.error(f"Failed to fetch interactions for record {record_id}: {e}", exc_info=True)
            # Return empty list instead of raising to prevent breaking the UI
            logger.warning(f"Returning empty interaction list due to error")
            return []

    def _normalize_note_type(self, note_type: Any) -> str:
        normalized = str(note_type or '').strip().lower()
        if normalized in {'clinical', 'clinical note'}:
            return 'Clinical Note'
        if normalized in {'peer', 'peer note'}:
            return 'Peer Note'
        if normalized in {'case', 'case note', 'case notes', 'case management', 'case management note'}:
            return 'Case Note'
        return 'Communication Log'