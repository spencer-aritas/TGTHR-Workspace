from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from typing import Any, Dict, Optional

from .sf_client import SalesforceClient, SFError

logger = logging.getLogger("audit_log")


class AuditLogService:
    """Thin wrapper for writing Audit_Log__c records in Salesforce."""

    OBJECT_NAME = "Audit_Log__c"

    def __init__(self) -> None:
        self.sf_client = SalesforceClient()

    def log_action(
        self,
        action_type: str,
        entity_id: Optional[str],
        details: str,
        *,
        user_id: Optional[str] = None,
        application: str = "PWA",
        audit_json: Optional[Dict[str, Any]] = None,
        compliance_reference: Optional[str] = None,
        created_by_integration: bool = True,
        event_type: Optional[str] = None,
        source_ip: Optional[str] = None,
        status: Optional[str] = None,
        timestamp: Optional[str] = None,
    ) -> None:
        record: Dict[str, Any] = {
            "Action__c": (action_type or "UNKNOWN")[:255],
            "Description__c": details[:32768] if details else "",
            "Application__c": application[:255] if application else "PWA",
            "Created_by_Integration__c": created_by_integration,
            "Timestamp__c": timestamp or datetime.now(timezone.utc).isoformat(),
        }

        if entity_id:
            if entity_id.startswith("001"):
                record["Record_Id__c"] = entity_id
            else:
                record["UUID__c"] = entity_id

        if user_id:
            record["User__c"] = user_id
        if event_type:
            normalized = self._normalize_event_type(event_type)
            if normalized:
                record["Event_Type__c"] = normalized
        if source_ip:
            record["Source_IP__c"] = source_ip[:255]
        if compliance_reference:
            record["Compliance_Reference__c"] = compliance_reference[:255]
        if status:
            record["Status__c"] = status[:255]
        if audit_json:
            try:
                record["Audit_JSON__c"] = json.dumps(audit_json)[:131000]
            except (TypeError, ValueError):
                record["Audit_JSON__c"] = json.dumps({"error": "serialization_failed"})

        try:
            self.sf_client.create(self.OBJECT_NAME, record)
        except SFError as exc:
            logger.error(f"Failed to create audit log entry: {exc}")
        except Exception as exc:
            logger.error(f"Unexpected error writing audit log: {exc}", exc_info=True)

    @staticmethod
    def _normalize_event_type(event_type: str) -> Optional[str]:
        """Translate internal event type tokens to Salesforce picklist values."""
        if not event_type:
            return None

        lookup = {
            "ACCESS": "Access",
            "MODIFY": "Modify",
            "CREATE": "Create",
            "DELETE": "Delete",
            "VIEW": "View",
        }

        upper = event_type.upper()
        if upper in lookup:
            return lookup[upper]

        title_case = event_type.title()
        return title_case[:255]


audit_logger = AuditLogService()
