
# server/app/salesforce/sf_client.py
from __future__ import annotations
import os
from pathlib import Path
import time
from pathlib import Path
from typing import Any, Dict, Optional, Tuple
from urllib.parse import quote_plus

import httpx
import jwt  # PyJWT

from ..settings import settings  

# -------------------- Errors --------------------

class SFAuthError(Exception):
    pass

class SFError(Exception):
    pass

# -------------------- Token cache --------------------
# Simple in-memory caches
_account_fields_cache: set[str] | None = None
# {sobject: describe_result}
_describe_cache: Dict[str, Dict[str, Any]] = {}
# (access_token, instance_url, expires_at_epoch)
_token_cache: Optional[Tuple[str, str, float]] = None

def clear_all_caches():
    """Clear all in-memory caches - useful for debugging cache issues"""
    global _account_fields_cache, _describe_cache, _token_cache, _person_rt_cache
    _account_fields_cache = None
    _describe_cache.clear()
    _token_cache = None
    _person_rt_cache = None
SERVER_DIR = Path(__file__).resolve().parents[1]
def _resolve_key_path(path_str: str) -> Path:
    raw = str(path_str).strip().strip('"').strip("'")
    # Map Docker-style '/app/...' to the actual server dir on Windows
    if os.name == "nt" and raw.startswith("/app/"):
        return (SERVER_DIR / raw.lstrip("/")).resolve()
    # Expand ~ and %VAR%
    p = Path(os.path.expanduser(os.path.expandvars(raw)))
    # If relative, resolve relative to server/ directory
    if not p.is_absolute():
        p = (SERVER_DIR / raw).resolve()
    return p

def _read_private_key() -> str:
    # Try environment variable first (for Docker)
    key_content = os.getenv("SF_JWT_PRIVATE_KEY")
    if key_content:
        return key_content.strip()
    
    # Fall back to file path
    path_str = getattr(settings, "SALESFORCE_PRIVATE_KEY_PATH", None)
    if not path_str or not str(path_str).strip():
        raise SFAuthError(
            "Neither SF_JWT_PRIVATE_KEY nor SALESFORCE_PRIVATE_KEY_PATH is set. "
            "Set SF_JWT_PRIVATE_KEY or SF_BENEFITS_JWT_PRIVATE_KEY_PATH in environment."
        )
    p = _resolve_key_path(path_str)
    if not p.exists():
        raise SFAuthError(f"Private key not found at: {p}")
    if p.is_dir():
        raise SFAuthError(f"Private key path points to a directory, not a file: {p}")
    return p.read_text(encoding="utf-8")

def _jwt_assertion() -> str:
    now = int(time.time())
    # For sandboxes the JWT audience is test.salesforce.com; for prod it's login.salesforce.com
    login_url = settings.SALESFORCE_LOGIN_URL.rstrip("/")
    aud = "https://test.salesforce.com" if "test.salesforce.com" in login_url else "https://login.salesforce.com"
    payload = {
        "iss": settings.SALESFORCE_CLIENT_ID,
        "sub": settings.SALESFORCE_USERNAME,
        "aud": aud,
        "exp": now + 180,  # 3 minutes
    }
    return jwt.encode(payload, _read_private_key(), algorithm="RS256")

def _get_token() -> Tuple[str, str]:
    """Return (access_token, instance_url), caching for ~14 minutes."""
    global _token_cache
    if _token_cache and (_token_cache[2] - time.time() > 30):
        return _token_cache[0], _token_cache[1]

    token_url = settings.SALESFORCE_LOGIN_URL.rstrip("/") + "/services/oauth2/token"
    data = {
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": _jwt_assertion(),
    }
    headers = {
        "Content-Type": "application/x-www-form-urlencoded"
    }
    resp = httpx.post(token_url, data=data, headers=headers, timeout=30.0, follow_redirects=True)
    if resp.status_code != 200:
        raise SFAuthError(f"JWT auth failed: {resp.status_code} {resp.text}")
    j = resp.json()
    access_token = j["access_token"]
    instance_url = j["instance_url"]
    _token_cache = (access_token, instance_url, time.time() + 14 * 60)
    return access_token, instance_url

# -------------------- REST helpers --------------------
# Utility to get a Program's Salesforce Id by name
def get_program_id(program_name: str) -> str | None:
    """Return the Salesforce Id for a Program by name, or None if not found."""
    safe_name = program_name.replace("'", "\\'")
    soql = f"SELECT Id FROM Program WHERE Name = '{safe_name}' LIMIT 1"
    res = _query(soql)
    records = res.get("records", [])
    if records:
        return records[0]["Id"]
    return None

def _api(path: str) -> str:
    """Build a REST API path with version, e.g. /services/data/v61.0/…"""
    ver = getattr(settings, "SALESFORCE_API_VERSION", "v61.0")
    return f"/services/data/{ver}{path}"

def _sf(path: str, *, method: str = "GET", json: Dict[str, Any] | None = None) -> Dict[str, Any]:
    """Call Salesforce REST API with a Bearer token."""
    token, base = _get_token()
    url = f"{base}{path}"
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    resp = httpx.request(method, url, headers=headers, json=json, timeout=30.0)
    # Salesforce returns errors as JSON arrays; propagate details for debugging
    if resp.status_code >= 400:
        raise SFError(f"{method} {path} -> {resp.status_code} {resp.text}")
    if not resp.text:
        return {}
    return resp.json()

def _query(soql: str) -> Dict[str, Any]:
    # Use proper URL encoding for SOQL
    return _sf(_api(f"/query/?q={quote_plus(soql)}"))

# -------------------- Person Account helpers --------------------
def _get_account_fields() -> set[str]:
    global _account_fields_cache
    if _account_fields_cache is not None:
        return _account_fields_cache
    desc = _sf(_api("/sobjects/Account/describe"))
    names = {f["name"] for f in desc.get("fields", [])}
    _account_fields_cache = names
    return names
_person_rt_cache: Optional[str] = None

def get_person_account_record_type_id() -> Optional[str]:
    """Return a Person Account RecordTypeId if available (or None)."""
    global _person_rt_cache
    # If explicitly configured, use it
    configured = getattr(settings, "SALESFORCE_PERSON_ACCOUNT_RECORD_TYPE_ID", None)
    if configured:
        return configured
    if _person_rt_cache:
        return _person_rt_cache

    res = _query(
        "SELECT Id, DeveloperName FROM RecordType "
        "WHERE SobjectType = 'Account' AND IsPersonType = true "
        "LIMIT 1"
    )
    records = res.get("records", [])
    if records:
        _person_rt_cache = records[0]["Id"]
        return _person_rt_cache
    return None

def create_person_account(person: Dict[str, Any]) -> str:
    """
    Create a Person Account (uses Person* and PersonMailing* fields).
    Also sets SSN 'Partial' on whichever status field your org exposes.
    Only sends fields that actually exist in the sandbox (describe-driven).
    """
    fields = _get_account_fields()

    rt_id = get_person_account_record_type_id()
    base: Dict[str, Any] = {
        # Required Person Account bits
        "RecordTypeId": rt_id,
        "LastName": person.get("lastName") or "Unknown",
        "FirstName": person.get("firstName"),

        # Person (Contact) fields on Account
        "PersonEmail": person.get("email"),
        "PersonMobilePhone": person.get("phone"),
        "PersonBirthdate": person.get("birthdate"),

        # *** Use Mailing (not Billing) for Person Accounts ***
        "PersonMailingStreet": person.get("street"),
        "PersonMailingCity": person.get("city"),
        "PersonMailingState": person.get("state"),
        "PersonMailingPostalCode": person.get("postalCode"),

        # Your custom fields (send only if they exist)
        "HMIS_Identifier_Number__c": person.get("hmisId"),
        "Alternate_Email__c": person.get("alternateEmail"),
        "Gender_Identity__pc": person.get("genderIdentity"),

        # SSN last 4 goes here (text)
        "Social_Security_Number__pc": person.get("ssnLast4"),

        # Text-area / misc person-level fields
        "Eye_Color__pc": person.get("eyeColor"),
        "Hair_Description__pc": person.get("hairDescription"),
        "Height__pc": person.get("height"),
        "Weight__pc": person.get("weight"),
        "Preferred_Language__pc": person.get("preferredLanguage"),
        "Translator_Needed__pc": person.get("translatorNeeded"),
        "Notable_Features_Tattoos__pc": person.get("notableFeatures"),
        "Gender_Identity_Other_Description__pc": person.get("genderIdentityOther"),
        "PersonPronouns__pc": person.get("pronouns"),
        "Pronouns_Other_Description__pc": person.get("pronounsOther"),
        "Race_and_Ethnicity__pc": person.get("raceEthnicity"),
        "Veteran_Service__pc": person.get("veteranService"),
        "Identified_Issues_Notes__pc": person.get("notes"),
        "UUID__c": person.get("uuid")
    }

    # Remove null/blank AND drop any fields not present in this org (describe-driven)
    payload: Dict[str, Any] = {}
    for k, v in base.items():
        if v is None or (isinstance(v, str) and v.strip() == ""):
            continue
        if k == "RecordTypeId" and rt_id is None:
            continue
        if k in fields:
            payload[k] = v

    ssn_status_fields = [
        "Social_Security_Number_Status__pc",
    ]
    for fname in ssn_status_fields:
        if fname in fields:
            payload[fname] = "Partial"
            break

    # Finally create in Salesforce
    res = _sf(_api("/sobjects/Account/"), method="POST", json=payload)
    return res["id"]

def ingest_encounter(encounter_data: Dict[str, Any]) -> Dict[str, Any]:
    """Call the Apex REST endpoint to ingest a complete encounter"""
    path = "/services/apexrest/ProgramEnrollmentService/ingestEncounter"
    return _sf(path, method="POST", json=encounter_data)

def create_interaction_summary_direct(record_id: str, notes: str, uuid: str, created_by_user_id: str = None) -> str:
    """Direct InteractionSummary creation with proper Name field"""
    from datetime import datetime
    
    # Determine if record_id is Account or Case and get account info
    if record_id.startswith('500'):  # Case ID prefix
        case = sobject_get("Case", record_id)
        account_id = case.get('AccountId')
        if not account_id:
            raise Exception(f"Case {record_id} has no associated Account")
        account = sobject_get("Account", account_id)
    else:  # Assume Account ID
        account_id = record_id
        account = sobject_get("Account", account_id)
    
    participant_name = f"{account.get('LastName', 'Unknown')}, {account.get('FirstName', '')}" if account.get('FirstName') else account.get('Name', 'Unknown')
    
    # Format date as MM/DD/YYYY
    today = datetime.now()
    formatted_date = f"{today.month:02d}/{today.day:02d}/{today.year}"
    
    # Get CreatedBy user name for title (the actual staff member, not integration user)
    staff_name = "Staff User"  # Default fallback
    if created_by_user_id:
        try:
            print(f"Looking up user name for ID: {created_by_user_id}")
            user_query = f"SELECT Name FROM User WHERE Id = '{created_by_user_id}' LIMIT 1"
            print(f"User query: {user_query}")
            user_result = query_soql(user_query)
            print(f"User query result: {user_result}")
            if user_result.get('records'):
                staff_name = user_result['records'][0].get('Name', 'Staff User')
                print(f"Found user name: {staff_name}")
            else:
                print("No user records found")
        except Exception as e:
            print(f"Could not get user name for {created_by_user_id}: {e}")
            staff_name = "Staff User"
    else:
        print("No created_by_user_id provided")
    
    # Format title as "Participant LastName, FirstName - Date - Staff Name"
    title = f"{participant_name} - {formatted_date} - {staff_name}"
    
    payload = {
        "Name": title,  # Required field!
        "RelatedRecordId": record_id,  # Standard polymorphic field (Case ID)
        "AccountId": account_id,  # Always the Account/Person Account ID
        "Date_of_Interaction__c": today.strftime("%Y-%m-%d"),
        "InteractionPurpose": "Communication Log",
        "MeetingNotes": notes,
        "UUID__c": uuid
    }
    
    if created_by_user_id:
        payload["CreatedById"] = created_by_user_id
    
    res = _sf(_api("/sobjects/InteractionSummary/"), method="POST", json=payload)
    return res["id"]

def call_interaction_summary_service(record_id: str, notes: str, uuid: str, created_by_user_id: str = None) -> str:
    """Call InteractionSummaryService with user context"""
    # Use direct creation with proper user context - supports both Account and Case IDs
    return create_interaction_summary_direct(record_id, notes, uuid, created_by_user_id)

def upsert_person_by_uuid(uuid: str, fields: dict) -> str:
    # PATCH /sobjects/Account/UUID__c/{uuid}
    path = _api(f"/sobjects/Account/UUID__c/{uuid}")
    _sf(path, method="PATCH", json=fields)
    # If record didn't exist, Salesforce creates it and returns 201 on a POST.
    # For PATCH, no body is returned on success. You can query back if you need the Id.
    rec = _query(f"SELECT Id FROM Account WHERE UUID__c = '{uuid}' LIMIT 1")
    return rec["records"][0]["Id"]
# -------------------- Optional example client --------------------

def query_soql(soql: str) -> dict:
    """Public helper to run a SOQL query and get the JSON response."""
    try:
        return _query(soql)
    except Exception as e:
        print(f"SOQL query failed: {soql} - Error: {e}")
        raise
def sobject_get(sobject: str, rec_id: str) -> dict:
    """GET a single sObject by Id."""
    return _sf(_api(f"/sobjects/{sobject}/{rec_id}"))

def sobject_update(sobject: str, rec_id: str, payload: dict) -> None:
    """PATCH an sObject by Id."""
    _sf(_api(f"/sobjects/{sobject}/{rec_id}"), method="PATCH", json=payload)

def sobject_upsert_external(sobject: str, ext_field: str, ext_value: str, payload: dict) -> None:
    """PATCH /sobjects/{sobject}/{ext_field}/{ext_value} (upsert by external id)."""
    _sf(_api(f"/sobjects/{sobject}/{ext_field}/{quote_plus(ext_value)}"), method="PATCH", json=payload)

class SalesforceClient:
    """Example wrapper if you want to group calls under a class."""
    def upsert_note(self, note: Dict[str, Any]) -> bool:
        # TODO: implement syncing notes to SF
        return True
    
    def query(self, soql: str, params: Dict[str, Any] = None) -> Dict[str, Any]:
        """Execute a SOQL query with optional parameters"""
        if params:
            # Simple parameter substitution for :paramName
            for key, value in params.items():
                soql = soql.replace(f":{key}", f"'{value}'")
        return _query(soql)
    
    def create(self, sobject: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new record in Salesforce"""
        return _sf(_api(f"/sobjects/{sobject}/"), method="POST", json=data)
    
    def call_apex_rest(self, service_name: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Call an Apex REST service"""
        path = f"/services/apexrest/{service_name}"
        return _sf(path, method="POST", json=data)

    def describe(self, sobject: str) -> Dict[str, Any]:
        """Describe metadata for a given sObject, cached for reuse."""
        key = sobject.lower()
        cached = _describe_cache.get(key)
        if cached:
            return cached
        desc = _sf(_api(f"/sobjects/{sobject}/describe"))
        _describe_cache[key] = desc
        return desc
__all__ = [
    "SFAuthError", "SFError",
    "query_soql",
    "sobject_get",
    "sobject_update",
    "sobject_upsert_external",
    "create_person_account",
    "upsert_person_by_uuid",
    "get_person_account_record_type_id",
    "ingest_encounter",
    "SalesforceClient",
]
