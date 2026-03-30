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
            
            query = """
            SELECT Id, Name, RelatedRecordId, Date_of_Interaction__c, 
                   AccountId, InteractionPurpose, Status,
                   Start_Time__c, End_Time__c, MeetingNotes,
                   CreatedDate, LastModifiedDate,
                   CreatedBy.Name,
                   Interview__c,
                   Interview__r.InterviewTemplateVersion__r.InterviewTemplate__r.Name,
                   Action_Required__c, Action_Assigned_To__c,
                   Requires_Manager_Approval__c, Manager_Signed__c,
                   Manager_Rejected__c, Manager_Approver__c
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
                    'Name': record.get('Name'),
                    'RelatedRecordId': record.get('RelatedRecordId'),
                    'AccountId': record.get('AccountId'),
                    'InteractionPurpose': record.get('InteractionPurpose'),
                    'Status': record.get('Status'),
                    'InteractionDate': record.get('Date_of_Interaction__c'),
                    'StartTime': record.get('Start_Time__c'),
                    'EndTime': record.get('End_Time__c'),
                    'Notes': record.get('MeetingNotes'),
                    'NoteType': record.get('InteractionPurpose'),
                    'CreatedByName': record.get('CreatedBy', {}).get('Name') if record.get('CreatedBy') else 'Unknown',
                    'CreatedDate': record.get('CreatedDate'),
                    'LastModifiedDate': record.get('LastModifiedDate'),
                    'InterviewId': record.get('Interview__c'),
                    'InterviewTemplateName': ((record.get('Interview__r') or {}).get('InterviewTemplateVersion__r') or {}).get('InterviewTemplate__r', {}).get('Name'),
                    'ActionRequired': record.get('Action_Required__c'),
                    'ActionAssignedTo': record.get('Action_Assigned_To__c'),
                    'RequiresManagerApproval': record.get('Requires_Manager_Approval__c', False),
                    'ManagerSigned': record.get('Manager_Signed__c', False),
                    'ManagerRejected': record.get('Manager_Rejected__c', False),
                    'ManagerApprover': record.get('Manager_Approver__c'),
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

    def get_interaction_detail(self, interaction_id: str) -> Dict[str, Any]:
        """Fetch a single InteractionSummary with hydrated related records."""
        try:
            logger.info(f"Fetching interaction detail: {interaction_id}")

            query = """
            SELECT Id, Name, RelatedRecordId, Date_of_Interaction__c,
                   AccountId, InteractionPurpose, Status,
                   Start_Time__c, End_Time__c, MeetingNotes,
                   CreatedDate, LastModifiedDate,
                   CreatedBy.Name,
                   Interview__c,
                   Action_Required__c, Action_Assigned_To__c,
                   Requires_Manager_Approval__c, Manager_Signed__c,
                   Manager_Rejected__c, Manager_Approver__c
            FROM InteractionSummary
            WHERE Id = :interactionId
            LIMIT 1
            """

            result = self.sf_client.query(query, {"interactionId": interaction_id})
            records = result.get('records', [])
            if not records:
                return None

            rec = records[0]

            # Determine signature state
            sig_state = 'none'
            if rec.get('Requires_Manager_Approval__c'):
                if rec.get('Manager_Signed__c'):
                    sig_state = 'signed'
                elif rec.get('Manager_Rejected__c'):
                    sig_state = 'rejected'
                else:
                    sig_state = 'pending'

            # Hydrate interview linkage if present
            interview_id = rec.get('Interview__c')
            interview_status = None
            interview_template_name = None
            if interview_id:
                try:
                    iv_result = self.sf_client.query(
                        "SELECT Id, Status__c, InterviewTemplateVersion__r.InterviewTemplate__r.Name "
                        "FROM Interview__c WHERE Id = :ivId LIMIT 1",
                        {"ivId": interview_id}
                    )
                    iv_records = iv_result.get('records', [])
                    if iv_records:
                        iv = iv_records[0]
                        interview_status = iv.get('Status__c')
                        ver = iv.get('InterviewTemplateVersion__r') or {}
                        tmpl = ver.get('InterviewTemplate__r') or {}
                        interview_template_name = tmpl.get('Name')
                except Exception as e:
                    logger.warning(f"Could not hydrate interview {interview_id}: {e}")

            case_id = rec.get('RelatedRecordId')

            # Hydrate interview form answers if linked
            interview_answers = []
            if interview_id:
                interview_answers = self._fetch_interview_answers(interview_id)

            # Hydrate related records from the Case
            goals = []
            benefits = []
            diagnoses = []
            cpt_codes = []
            if case_id:
                goals = self._fetch_goals(case_id)
                benefits = self._fetch_benefits(case_id)
                diagnoses = self._fetch_diagnoses(case_id)
                cpt_codes = self._fetch_cpt_codes(case_id)

            detail = {
                'summary': {
                    'id': rec.get('Id'),
                    'name': rec.get('Name'),
                    'kind': rec.get('InteractionPurpose'),
                    'status': rec.get('Status'),
                    'interactionPurpose': rec.get('InteractionPurpose'),
                },
                'chronology': {
                    'interactionDate': rec.get('Date_of_Interaction__c'),
                    'startTime': rec.get('Start_Time__c'),
                    'endTime': rec.get('End_Time__c'),
                    'createdDate': rec.get('CreatedDate'),
                    'lastModifiedDate': rec.get('LastModifiedDate'),
                },
                'ownership': {
                    'createdByName': rec.get('CreatedBy', {}).get('Name') if rec.get('CreatedBy') else None,
                    'actionAssignedToName': rec.get('Action_Assigned_To__c'),
                    'managerApproverName': rec.get('Manager_Approver__c'),
                },
                'content': {
                    'notesHtml': rec.get('MeetingNotes'),
                    'notesText': rec.get('MeetingNotes'),
                },
                'linkage': {
                    'caseId': case_id,
                    'accountId': rec.get('AccountId'),
                    'interviewId': interview_id,
                    'interviewStatus': interview_status,
                    'interviewTemplateName': interview_template_name,
                },
                'signature': {
                    'requiresManagerApproval': rec.get('Requires_Manager_Approval__c', False),
                    'managerSigned': rec.get('Manager_Signed__c', False),
                    'managerRejected': rec.get('Manager_Rejected__c', False),
                    'signatureState': sig_state,
                },
                'actions': {
                    'canOpenInterview': interview_id is not None,
                    'canAddQuickNote': True,
                    'canRequestSignature': sig_state in ('none', 'pending'),
                },
                'relatedRecords': {
                    'goals': goals,
                    'benefits': benefits,
                    'diagnoses': diagnoses,
                    'cptCodes': cpt_codes,
                },
                'interviewAnswers': interview_answers,
            }

            return detail
        except Exception as e:
            logger.error(f"Failed to fetch interaction detail {interaction_id}: {e}", exc_info=True)
            raise

    # ── Related record hydration helpers ──────────────────────────────

    def _fetch_interview_answers(self, interview_id: str) -> List[Dict[str, Any]]:
        """Fetch InterviewAnswer__c records with question labels, grouped by section."""
        try:
            query = (
                "SELECT Id, Section__c, Question_API_Name__c, "
                "Response_Text__c, Response_Number__c, Response_Boolean__c, "
                "Response_Picklist__c, Response_Date__c, "
                "InterviewQuestion__r.Label__c, InterviewQuestion__r.Section__c, "
                "InterviewQuestion__r.Order__c, InterviewQuestion__r.Response_Type__c "
                "FROM InterviewAnswer__c "
                "WHERE Interview__c = :interviewId "
                "ORDER BY InterviewQuestion__r.Section__c, InterviewQuestion__r.Order__c"
            )
            result = self.sf_client.query(query, {"interviewId": interview_id})
            answers = []
            for r in result.get('records', []):
                q = r.get('InterviewQuestion__r') or {}
                # Determine display value from whichever response field is populated
                value = (
                    r.get('Response_Text__c')
                    or r.get('Response_Picklist__c')
                    or (str(r.get('Response_Number__c')) if r.get('Response_Number__c') is not None else None)
                    or (str(r.get('Response_Date__c')) if r.get('Response_Date__c') else None)
                    or (('Yes' if r.get('Response_Boolean__c') else 'No') if r.get('Response_Boolean__c') is not None else None)
                    or ''
                )
                answers.append({
                    'section': q.get('Section__c') or r.get('Section__c') or 'General',
                    'label': q.get('Label__c') or r.get('Question_API_Name__c') or 'Question',
                    'value': value,
                    'responseType': q.get('Response_Type__c'),
                    'order': q.get('Order__c'),
                })
            return answers
        except Exception as e:
            logger.warning(f"Could not fetch interview answers for {interview_id}: {e}")
            return []

    def _fetch_goals(self, case_id: str) -> List[Dict[str, Any]]:
        try:
            result = self.sf_client.query(
                "SELECT Id, Name, Status__c, Description__c "
                "FROM Goal__c WHERE Case__c = :caseId ORDER BY Name ASC LIMIT 50",
                {"caseId": case_id}
            )
            return [
                {'id': r.get('Id'), 'name': r.get('Name'),
                 'status': r.get('Status__c'), 'description': r.get('Description__c')}
                for r in result.get('records', [])
            ]
        except Exception as e:
            logger.warning(f"Could not fetch goals for case {case_id}: {e}")
            return []

    def _fetch_benefits(self, case_id: str) -> List[Dict[str, Any]]:
        try:
            result = self.sf_client.query(
                "SELECT Id, Name, Status__c, Amount__c "
                "FROM Benefit__c WHERE Case__c = :caseId ORDER BY Name ASC LIMIT 50",
                {"caseId": case_id}
            )
            return [
                {'id': r.get('Id'), 'name': r.get('Name'),
                 'status': r.get('Status__c'), 'amount': r.get('Amount__c')}
                for r in result.get('records', [])
            ]
        except Exception as e:
            logger.warning(f"Could not fetch benefits for case {case_id}: {e}")
            return []

    def _fetch_diagnoses(self, case_id: str) -> List[Dict[str, Any]]:
        try:
            result = self.sf_client.query(
                "SELECT Id, Name, Code__c, Description__c "
                "FROM Diagnosis__c WHERE Case__c = :caseId ORDER BY Name ASC LIMIT 50",
                {"caseId": case_id}
            )
            return [
                {'id': r.get('Id'), 'name': r.get('Name'),
                 'code': r.get('Code__c'), 'description': r.get('Description__c')}
                for r in result.get('records', [])
            ]
        except Exception as e:
            logger.warning(f"Could not fetch diagnoses for case {case_id}: {e}")
            return []

    def _fetch_cpt_codes(self, case_id: str) -> List[Dict[str, Any]]:
        try:
            result = self.sf_client.query(
                "SELECT Id, Code__c, Description__c "
                "FROM CPT_Code__c WHERE Case__c = :caseId ORDER BY Code__c ASC LIMIT 50",
                {"caseId": case_id}
            )
            return [
                {'id': r.get('Id'), 'code': r.get('Code__c'),
                 'description': r.get('Description__c')}
                for r in result.get('records', [])
            ]
        except Exception as e:
            logger.warning(f"Could not fetch CPT codes for case {case_id}: {e}")
            return []