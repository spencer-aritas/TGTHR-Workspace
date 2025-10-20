# server/app/sync_helpers.py
from __future__ import annotations

import uuid
from typing import Dict, List, Iterable

from .db import DuckClient
from .settings import settings
from .salesforce.sf_client import query_soql, sobject_update

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
    soql = (
        f"SELECT {', '.join(settings.SF_ACCOUNT_FIELDS)} "
        f"FROM {settings.SF_ACCOUNT_OBJECT} "
        f"WHERE IsPersonAccount = TRUE AND Id IN ({soql_in_list(ids)})"
    )
    return query_soql(soql).get("records", [])

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
            a.get("PersonFirstName"),
            a.get("PersonLastName"),
            a.get("PersonEmail"),
            a.get("Phone"),
            a.get("PersonBirthdate"),
            a.get("LastModifiedDate"),
        ))
    return id_to_uuid

def upsert_enrollments(
    db: DuckClient,
    rows: List[dict],
    prog_uuid_by_id: Dict[str, str],
    acct_uuid_by_id: Dict[str, str],
) -> Dict[str, str]:
    """Upsert enrollments to database, returns SF ID -> UUID mapping"""
    enr_uuid_by_id: Dict[str, str] = {}
    for e in rows:
        program_uuid = prog_uuid_by_id.get(e.get("ProgramId"))
        participant_uuid = acct_uuid_by_id.get(e.get("AccountId"))
        if not (program_uuid and participant_uuid):
            continue

        enr_uuid = ensure_uuid(e.get("UUID__c"))
        if not e.get("UUID__c") and settings.TGTHR_WRITE_MISSING_UUIDS:
            try:
                sobject_update(settings.SF_PROGRAM_ENROLLMENT_OBJECT, e["Id"], {"UUID__c": enr_uuid})
            except Exception:
                pass

        enr_uuid_by_id[e["Id"]] = enr_uuid

        db.execute("""
            INSERT OR REPLACE INTO program_enrollments
                (uuid, sfid, program_id, enrollee_id,
                 start_date, end_date, status, entered_hmis, exited_hmis, last_modified_date)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            enr_uuid,
            e.get("Id"),
            e.get("ProgramId"),
            e.get("AccountId"),
            e.get("StartDate"),
            e.get("EndDate"),
            e.get("Status"),
            bool(e.get("Entered_into_HMIS__c")),
            bool(e.get("Exited_from_HMIS__c")),
            e.get("LastModifiedDate"),
        ))
    return enr_uuid_by_id