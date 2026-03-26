# server/app/salesforce/interview_answer_service.py
import logging
from datetime import date, datetime, timezone
from typing import Dict, Any, Optional
from uuid import uuid4

import httpx

from ..settings import settings
from .sf_client import _sf, _api, _query, _get_token, call_interaction_summary_service
from .assessment_service import AssessmentServiceClient

logger = logging.getLogger("interview_answer_service")

class InterviewAnswerService:
    """Service for managing Interview Answers"""

    def __init__(self):
        self._describe_cache: Dict[str, set[str]] = {}
    
    def save_interview_answers(
        self,
        case_id: str,
        template_version_id: str,
        answers: Dict[str, str],
        ssrs_assessment_id: Optional[str] = None,
    ) -> Dict[str, Any]:
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
            
            case_context = self._get_case_context(case_id)
            template_context = self._get_template_context(template_version_id)
            questions = self._get_template_questions(template_version_id)
            questions_by_id = {record['Id']: record for record in questions}

            interaction_summary_id = self._create_interaction_summary(
                case_id,
                case_context.get('AccountId'),
                template_context.get('template_name')
            )

            assessment_id = self._create_assessment(
                case_id,
                case_context.get('AccountId'),
                template_context.get('template_name')
            )

            interview_data = self._build_interview_payload(
                case_id,
                case_context.get('AccountId'),
                template_version_id,
                template_context.get('template_name'),
                interaction_summary_id
            )
            
            logger.debug(f"Creating Interview header: {interview_data}")
            interview_result = _sf(_api("/sobjects/Interview__c/"), method="POST", json=interview_data)
            
            if not interview_result or 'id' not in interview_result:
                raise Exception(f"Failed to create Interview record: {interview_result}")
            
            interview_id = interview_result['id']
            logger.info(f"Created Interview record: {interview_id}")

            assessment_service = AssessmentServiceClient()

            if assessment_id:
                assessment_service.link_assessment_to_interaction(assessment_id, interaction_summary_id)
                assessment_service.link_assessment_to_interview(assessment_id, interview_id)

            if ssrs_assessment_id:
                assessment_service.link_assessment_to_interaction(ssrs_assessment_id, interaction_summary_id)
                assessment_service.link_assessment_to_interview(ssrs_assessment_id, interview_id)
            
            # Now create InterviewAnswer__c records for each answer
            answer_count = 0
            assessment_updates: Dict[str, Any] = {}
            for question_id, answer_value in answers.items():
                try:
                    question = questions_by_id.get(question_id)
                    if not question:
                        logger.warning(f"Question metadata not found for question {question_id}; skipping")
                        continue

                    answer_record = {
                        'Name': f"Answer - {question.get('API_Name__c') or question_id}",
                        'Interview__c': interview_id,
                        'InterviewQuestion__c': question_id
                    }

                    if self._field_exists('InterviewAnswer__c', 'Question_API_Name__c') and question.get('API_Name__c'):
                        answer_record['Question_API_Name__c'] = question['API_Name__c']
                    if self._field_exists('InterviewAnswer__c', 'Section__c') and question.get('Section__c'):
                        answer_record['Section__c'] = question['Section__c']

                    self._assign_answer_value(answer_record, question.get('Response_Type__c'), answer_value)
                    
                    logger.debug(f"Creating InterviewAnswer: {answer_record}")
                    answer_result = _sf(_api("/sobjects/InterviewAnswer__c/"), method="POST", json=answer_record)
                    
                    if answer_result and 'id' in answer_result:
                        answer_count += 1
                    else:
                        logger.warning(f"Failed to create answer for question {question_id}: {answer_result}")

                    maps_to = question.get('Maps_To__c')
                    if assessment_id and maps_to and maps_to.startswith('Assessment__c.'):
                        assessment_field = maps_to.split('.', 1)[1]
                        if self._field_exists('Assessment__c', assessment_field):
                            coerced_value = self._coerce_value_for_assessment(question.get('Response_Type__c'), answer_value)
                            if coerced_value is not None:
                                assessment_updates[assessment_field] = coerced_value
                        
                except Exception as e:
                    logger.warning(f"Failed to create answer for question {question_id}: {e}", exc_info=True)
                    # Continue with other answers even if one fails
                    continue

            if assessment_id and assessment_updates:
                logger.debug(f"Updating Assessment {assessment_id} with mapped answers: {assessment_updates}")
                _sf(
                    _api(f"/sobjects/Assessment__c/{assessment_id}"),
                    method="PATCH",
                    json=assessment_updates
                )

            document_generated = self._trigger_document_generation(interaction_summary_id)
            
            logger.info(f"Created {answer_count} InterviewAnswer records")
            
            return {
                'success': True,
                'interview_id': interview_id,
                'interaction_summary_id': interaction_summary_id,
                'document_generated': document_generated,
                'answers_count': answer_count,
                'message': f'Successfully saved interview with {answer_count} answers'
            }
            
        except Exception as e:
            logger.error(f"Failed to save interview answers: {e}", exc_info=True)
            raise

    def _get_case_context(self, case_id: str) -> Dict[str, Any]:
        result = _query(f"SELECT Id, AccountId FROM Case WHERE Id = '{case_id}' LIMIT 1")
        records = result.get('records', [])
        if not records:
            raise ValueError(f"Case not found: {case_id}")
        return records[0]

    def _get_template_context(self, template_version_id: str) -> Dict[str, Any]:
        result = _query(
            "SELECT Id, Name, InterviewTemplate__r.Name "
            f"FROM InterviewTemplateVersion__c WHERE Id = '{template_version_id}' LIMIT 1"
        )
        records = result.get('records', [])
        if not records:
            raise ValueError(f"Interview template version not found: {template_version_id}")
        record = records[0]
        template_rel = record.get('InterviewTemplate__r') or {}
        return {
            'version_name': record.get('Name'),
            'template_name': template_rel.get('Name') or record.get('Name') or 'Interview'
        }

    def _get_template_questions(self, template_version_id: str) -> list[Dict[str, Any]]:
        soql = f"""
            SELECT Id, API_Name__c, Section__c, Response_Type__c, Maps_To__c
            FROM InterviewQuestion__c
            WHERE InterviewTemplateVersion__c = '{template_version_id}'
            ORDER BY Order__c ASC, Name ASC
        """
        result = _query(soql)
        return result.get('records', [])

    def _get_object_fields(self, object_api_name: str) -> set[str]:
        cached = self._describe_cache.get(object_api_name)
        if cached is not None:
            return cached

        describe_result = _sf(_api(f"/sobjects/{object_api_name}/describe"))
        fields = {field['name'] for field in describe_result.get('fields', [])}
        self._describe_cache[object_api_name] = fields
        return fields

    def _field_exists(self, object_api_name: str, field_api_name: str) -> bool:
        return field_api_name in self._get_object_fields(object_api_name)

    def _build_interview_payload(
        self,
        case_id: str,
        account_id: Optional[str],
        template_version_id: str,
        template_name: str,
        interaction_summary_id: str,
    ) -> Dict[str, Any]:
        fields = self._get_object_fields('Interview__c')
        payload: Dict[str, Any] = {}
        timestamp = self._utc_now_iso()

        if 'Name' in fields:
            payload['Name'] = f"{template_name} - {date.today().isoformat()}"
        if 'Case__c' in fields:
            payload['Case__c'] = case_id
        if account_id and 'Client__c' in fields:
            payload['Client__c'] = account_id
        if 'InterviewTemplateVersion__c' in fields:
            payload['InterviewTemplateVersion__c'] = template_version_id
        if interaction_summary_id and 'Interaction_Summary__c' in fields:
            payload['Interaction_Summary__c'] = interaction_summary_id
        if 'Status__c' in fields:
            payload['Status__c'] = 'Submitted'
        if 'Started_On__c' in fields:
            payload['Started_On__c'] = timestamp
        if 'Completed_On__c' in fields:
            payload['Completed_On__c'] = timestamp
        if 'UUID__c' in fields:
            payload['UUID__c'] = str(uuid4())

        return payload

    def _create_interaction_summary(
        self,
        case_id: str,
        account_id: Optional[str],
        template_name: str,
    ) -> str:
        interaction_date = date.today().isoformat()
        timestamp = self._utc_now_iso()
        notes = f"{template_name} completed in PWA" if template_name else 'Interview completed in PWA'

        return call_interaction_summary_service(
            record_id=case_id,
            account_id=account_id,
            notes=notes,
            interaction_date=interaction_date,
            start_time=timestamp,
            end_time=timestamp,
            interaction_purpose='Interview',
            uuid=f"pwa_interview_{uuid4()}",
            created_by_user_id=''
        )

    def _trigger_document_generation(self, interaction_summary_id: str) -> bool:
        if not interaction_summary_id:
            return False

        try:
            _, instance_url = _get_token()
            response = httpx.post(
                self._get_docgen_url('/trigger-interview-doc'),
                json={
                    'record_id': interaction_summary_id,
                    'preview': False,
                    'instance_url': instance_url,
                },
                timeout=120.0,
            )
            response.raise_for_status()
            payload = response.json()
            return bool(payload.get('contentDocumentId'))
        except Exception as exc:
            logger.warning(
                'Interview saved but document generation failed for interaction %s: %s',
                interaction_summary_id,
                exc,
            )
            return False

    def _get_docgen_url(self, path: str) -> str:
        base_url = getattr(settings, 'DOCGEN_BASE_URL', 'http://docgen:8000').rstrip('/')
        return f"{base_url}{path}"

    def _utc_now_iso(self) -> str:
        return datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')

    def _create_assessment(
        self,
        case_id: str,
        account_id: Optional[str],
        template_name: str,
    ) -> Optional[str]:
        try:
            fields = self._get_object_fields('Assessment__c')
        except Exception as exc:
            logger.warning(f"Assessment__c describe failed; skipping assessment create: {exc}")
            return None

        payload: Dict[str, Any] = {}
        if 'Case__c' in fields:
            payload['Case__c'] = case_id
        if account_id and 'Participant__c' in fields:
            payload['Participant__c'] = account_id
        if 'Assessment_Date__c' in fields:
            payload['Assessment_Date__c'] = date.today().isoformat()
        if 'Status__c' in fields:
            payload['Status__c'] = 'In Progress'
        if template_name and 'Assessment_Type__c' in fields:
            payload['Assessment_Type__c'] = template_name

        if not payload:
            return None

        result = _sf(_api('/sobjects/Assessment__c/'), method='POST', json=payload)
        return result.get('id')

    def _assign_answer_value(self, answer_record: Dict[str, Any], response_type: Optional[str], raw_value: str) -> None:
        normalized_type = (response_type or 'text').strip().lower().replace('-', '_')

        if normalized_type in {'number', 'decimal', 'score'}:
            if self._field_exists('InterviewAnswer__c', 'Response_Number__c'):
                answer_record['Response_Number__c'] = float(raw_value)
                return

        if normalized_type == 'boolean':
            parsed_boolean = self._parse_boolean(raw_value)
            if parsed_boolean is not None and self._field_exists('InterviewAnswer__c', 'Response_Boolean__c'):
                answer_record['Response_Boolean__c'] = parsed_boolean
                return

        if normalized_type == 'date':
            if self._field_exists('InterviewAnswer__c', 'Response_Date__c'):
                answer_record['Response_Date__c'] = raw_value
                return

        if normalized_type == 'datetime':
            if self._field_exists('InterviewAnswer__c', 'Response_DateTime__c'):
                answer_record['Response_DateTime__c'] = raw_value
                return

        if normalized_type in {'picklist', 'multi_picklist', 'multipicklist', 'radios'}:
            if self._field_exists('InterviewAnswer__c', 'Response_Picklist__c'):
                answer_record['Response_Picklist__c'] = raw_value
                return

        for field_name in ('Response_Text__c', 'Response_Value__c', 'Answer_Value__c'):
            if self._field_exists('InterviewAnswer__c', field_name):
                answer_record[field_name] = raw_value
                return

    def _coerce_value_for_assessment(self, response_type: Optional[str], raw_value: str) -> Any:
        normalized_type = (response_type or 'text').strip().lower().replace('-', '_')

        if normalized_type in {'number', 'decimal', 'score'}:
            return float(raw_value)
        if normalized_type == 'boolean':
            return self._parse_boolean(raw_value)
        return raw_value

    def _parse_boolean(self, raw_value: str) -> Optional[bool]:
        normalized = (raw_value or '').strip().lower()
        if normalized in {'true', 'yes', '1'}:
            return True
        if normalized in {'false', 'no', '0'}:
            return False
        return None
