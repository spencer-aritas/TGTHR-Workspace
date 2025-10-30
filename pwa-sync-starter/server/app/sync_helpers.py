# server/app/sync_helpers.py
from __future__ import annotations
import logging
import uuid
from typing import Dict, List, Iterable, Optional

from .db import DuckClient
from .settings import settings

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)
from .salesforce.sf_client import query_soql, sobject_update, SFError

def ensure_uuid(val: str | None) -> str:
    """Ensure a valid UUID, generate one if missing"""
    return val.strip() if isinstance(val, str) and val.strip() else str(uuid.uuid4())

def soql_escape(s: str) -> str:
    """Escape string for SOQL queries"""
    return s.replace("\\", "\\\\").replace("'", "\\'")

def soql_in_list(ids: Iterable[str]) -> str:
    """Format list of IDs for SOQL IN clause"""
    return ",".join(f"'{i}'" for i in ids)

def program_where_clause(prefixes: List[str]) -> str:
    """Generate WHERE clause for program name filtering"""
    clauses = [f"Name LIKE '{soql_escape(p)}%'" for p in prefixes if p and p.strip()]
    return f" WHERE ({' OR '.join(clauses)})" if clauses else ""

def fetch_programs() -> List[dict]:
    """Fetch programs from Salesforce based on configured names"""
    where = program_where_clause(settings.PROGRAM_NAMES)
    soql = (
        f"SELECT {', '.join(settings.SF_PROGRAM_FIELDS)} "
        f"FROM {settings.SF_PROGRAM_OBJECT}{where} "
        f"ORDER BY Name"
    )
    return query_soql(soql).get("records", [])

def fetch_enrollments_for_programs(program_ids: List[str]) -> List[dict]:
    """Fetch active enrollments for specified programs"""
    ids = [i for i in program_ids if i]
    if not ids:
        return []
    soql = (
        f"SELECT {', '.join(settings.SF_PROGRAM_ENROLLMENT_FIELDS)} "
        f"FROM {settings.SF_PROGRAM_ENROLLMENT_OBJECT} "
        f"WHERE ProgramId IN ({soql_in_list(ids)}) "
        f"AND (Status = 'Active' OR EndDate = NULL OR EndDate >= TODAY) "
        f"ORDER BY LastModifiedDate DESC"
    )
    return query_soql(soql).get("records", [])

def fetch_accounts(account_ids: Iterable[str]) -> List[dict]:
    """Fetch person accounts by IDs"""
    ids = [i for i in account_ids if i]
    if not ids:
        return []
    fields = settings.SF_ACCOUNT_FIELDS
    soql = (
        f"SELECT {', '.join(fields)} "
        f"FROM {settings.SF_ACCOUNT_OBJECT} "
        f"WHERE IsPersonAccount = TRUE AND Id IN ({soql_in_list(ids)})"
    )
    try:
        return query_soql(soql).get("records", [])
    except SFError as exc:
        if "INVALID_FIELD" not in str(exc):
            raise
        fallback_fields = ["Id", "IsPersonAccount", "Name", "Phone", "UUID__c", "LastModifiedDate"]
        fallback_soql = (
            f"SELECT {', '.join(fallback_fields)} "
            f"FROM {settings.SF_ACCOUNT_OBJECT} "
            f"WHERE Id IN ({soql_in_list(ids)})"
        )
        return query_soql(fallback_soql).get("records", [])

def upsert_programs(db: DuckClient, rows: List[dict]) -> Dict[str, str]:
    """Upsert programs to database, returns SF ID -> UUID mapping"""
    id_to_uuid: Dict[str, str] = {}
    for r in rows:
        p_uuid = ensure_uuid(r.get("UUID__c"))
        if not r.get("UUID__c") and settings.TGTHR_WRITE_MISSING_UUIDS:
            try:
                sobject_update(settings.SF_PROGRAM_OBJECT, r["Id"], {"UUID__c": p_uuid})
            except Exception:
                pass

        id_to_uuid[r["Id"]] = p_uuid

        db.execute("""
            INSERT OR REPLACE INTO programs (uuid, sfid, name, last_modified_date)
            VALUES (?, ?, ?, ?)
        """, (p_uuid, r.get("Id"), r.get("Name"), r.get("LastModifiedDate")))
    return id_to_uuid

def upsert_participants(db: DuckClient, rows: List[dict]) -> Dict[str, str]:
    """Upsert participants to database, returns SF ID -> UUID mapping"""
    id_to_uuid: Dict[str, str] = {}
    for a in rows:
        if not a.get("IsPersonAccount"):
            continue

        pa_uuid = ensure_uuid(a.get("UUID__c"))
        if not a.get("UUID__c") and settings.TGTHR_WRITE_MISSING_UUIDS:
            try:
                sobject_update(settings.SF_ACCOUNT_OBJECT, a["Id"], {"UUID__c": pa_uuid})
            except Exception:
                pass

        id_to_uuid[a["Id"]] = pa_uuid

        db.execute("""
            INSERT OR REPLACE INTO participants
                (uuid, sfid, first_name, last_name, preferred_name, email, phone, date_of_birth, updated_at)
            VALUES (?, ?, ?, ?, NULL, ?, ?, ?, ?)
        """, (
            pa_uuid,
            a.get("Id"),
            _extract_first_name(a),
            _extract_last_name(a),
            a.get("PersonEmail"),
            a.get("Phone"),
            a.get("PersonBirthdate"),
            a.get("LastModifiedDate"),
        ))
    return id_to_uuid

from typing import Any, Dict, List, Optional

def upsert_enrollments(
    db: DuckClient,
    rows: List[Dict[str, Any]],
    prog_uuid_by_id: Dict[str, str],
    acct_uuid_by_id: Dict[str, str],
) -> Dict[str, str]:
    """Upsert enrollments to database, returns SF ID -> UUID mapping"""
    enr_uuid_by_id: Dict[str, str] = {}

    for e in rows:
        # Safely extract required string IDs
        sf_enr_id: Optional[str] = e.get("Id") if isinstance(e.get("Id"), str) else None
        program_id: Optional[str] = e.get("ProgramId") if isinstance(e.get("ProgramId"), str) else None
        account_id: Optional[str] = e.get("AccountId") if isinstance(e.get("AccountId"), str) else None

        if not sf_enr_id:
            logger.debug("[sync] Skipping enrollment without Id: %s", e)
            continue

        if not program_id or not account_id:
            logger.debug(
                "[sync] Skipping enrollment %s due to missing ProgramId/AccountId (ProgramId=%r, AccountId=%r)",
                sf_enr_id, program_id, account_id
            )
            continue

        program_uuid = prog_uuid_by_id.get(program_id)
        participant_uuid = acct_uuid_by_id.get(account_id)
        if not (program_uuid and participant_uuid):
            logger.debug(
                "[sync] Skipping enrollment %s; missing mapped uuids (program_uuid=%r, participant_uuid=%r)",
                sf_enr_id, program_uuid, participant_uuid
            )
            continue

        # Ensure or generate UUID for the enrollment
        existing_uuid = e.get("UUID__c") if isinstance(e.get("UUID__c"), str) else None
        enr_uuid = ensure_uuid(existing_uuid)

        # Optionally write back the UUID to SF if missing
        if not existing_uuid and settings.TGTHR_WRITE_MISSING_UUIDS:
            try:
                sobject_update(settings.SF_PROGRAM_ENROLLMENT_OBJECT, sf_enr_id, {"UUID__c": enr_uuid})
            except Exception as ex:
                logger.warning("[sync] Failed to write UUID__c back to SF for %s: %s", sf_enr_id, ex)

        enr_uuid_by_id[sf_enr_id] = enr_uuid

        # Insert/replace locally
        db.execute(
            """
            INSERT OR REPLACE INTO program_enrollments
                (uuid, sfid, program_id, enrollee_id,
                 start_date, end_date, status, entered_hmis, exited_hmis, last_modified_date)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                enr_uuid,
                sf_enr_id,
                program_id,
                account_id,
                e.get("StartDate"),
                e.get("EndDate"),
                e.get("Status"),
                bool(e.get("Entered_into_HMIS__c")),
                bool(e.get("Exited_from_HMIS__c")),
                e.get("LastModifiedDate"),
            ),
        )

    return enr_uuid_by_id

def _extract_first_name(account: dict) -> str | None:
    if account.get("PersonFirstName"):
        return account.get("PersonFirstName")
    name = account.get("Name")
    if name:
        parts = name.split()
        if parts:
            return parts[0]
    return None

def _extract_last_name(account: dict) -> str | None:
    if account.get("PersonLastName"):
        return account.get("PersonLastName")
    name = account.get("Name")
    if name:
        parts = name.split()
        if len(parts) > 1:
            return " ".join(parts[1:])
        return parts[0]
    return None
