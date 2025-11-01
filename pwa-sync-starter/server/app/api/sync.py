# server/app/api/sync.py
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing import List, Literal, Dict, Any, Optional
from ..models.db import SessionLocal
from ..schema import Note, Meta
from ..salesforce.sf_client import _get_token, _api, _sf, get_person_account_record_type_id, create_person_account
from ..salesforce.audit_log_service import audit_logger
from ..sync_runner import SyncRunner
import uuid
import logging

logger = logging.getLogger("sync")

router = APIRouter()
from ..salesforce.intake_service import process_full_intake as create_program_intake
# ---------------- Existing sync (notes) --------------------------------------
class Mutation(BaseModel):
    from pydantic import Field
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    table: Literal['notes']
    op: Literal['insert','update','delete']
    payload: dict
    clientTs: str
    deviceId: str

def get_device_user(device_id: str, db: Session) -> dict:
    """Get user context for device from registration"""
    from ..models.db import get_db as get_sqlite_db
    sqlite_db = get_sqlite_db()
    
    logger.info(f"Looking up device registration for: {device_id}")
    result = sqlite_db.execute("""
        SELECT user_id, sf_user_id FROM device_registrations 
        WHERE device_id = ?
    """, (device_id,)).fetchone()
    
    logger.info(f"Device registration query result: {result}")
    sqlite_db.close()
    
    if result:
        user_context = {"userId": result[0], "sfUserId": result[1]}
        logger.info(f"Returning user context: {user_context}")
        return user_context
    
    logger.info("No device registration found")
    return {"userId": None, "sfUserId": None}

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_next_version(db: Session) -> int:
    rec = db.get(Meta, 'serverVersion')
    v = int(rec.value) if rec else 0
    v += 1
    if rec:
        rec.value = str(v)
    else:
        db.add(Meta(key='serverVersion', value=str(v)))
    return v

@router.post('/sync/upload')
def upload(mutations: List[Mutation], db: Session = Depends(get_db)):
    accepted = []
    serverVersion = None
    for m in mutations:
        if m.table == 'notes':
            note_id = m.payload.get('id')
            if m.op in ('insert','update'):
                n = db.get(Note, note_id) or Note(id=note_id)
                n.enrolleeId = m.payload.get('enrolleeId', '')
                n.body = m.payload.get('body', '')
                n.createdAt = m.payload.get('createdAt', '')  # Default to empty string if not provided
                n.updatedAt = m.payload.get('updatedAt', '')  # Default to empty string if not provided
                n.deviceId = m.payload.get('deviceId', '')    # Default to empty string if not provided
                serverVersion = get_next_version(db)
                n.version = serverVersion
                db.add(n)
            elif m.op == 'delete':
                n = db.get(Note, note_id)
                if n: db.delete(n)
                serverVersion = get_next_version(db)
            accepted.append(m.id)
    db.commit()
    if serverVersion is None:
        serverVersion = int((db.get(Meta, 'serverVersion') or Meta(key='serverVersion', value='0')).value)
    return { 'acceptedIds': accepted, 'serverVersion': serverVersion }

@router.get('/sync/pull')
def pull(since: int = 0, db: Session = Depends(get_db)):
    rows = db.query(Note).filter(Note.version > since).all()
    notes = [{
        'id': r.id,
        'enrolleeId': r.enrolleeId,
        'body': r.body,
        'createdAt': r.createdAt,
        'updatedAt': r.updatedAt,
        'deviceId': r.deviceId,
        'version': r.version
    } for r in rows]
    current = db.get(Meta, 'serverVersion')
    v = int(current.value) if current else 0
    return { 'notes': notes, 'serverVersion': v }

# ---------------- New endpoints for PWA MVP ----------------------------------
class PersonPayload(BaseModel):
    localId: str
    person: Dict[str, Any]  # { firstName, lastName, email, ... }

class IntakePayload(BaseModel):
    localId: str
    intake: Dict[str, Any]  # { personLocalId?, programId, startDate, consentSigned, ... }

@router.post('/sync/PersonAccount')
def sync_person_account(data: PersonPayload, db: Session = Depends(get_db)):
    data.person["uuid"] = data.localId
    
    # Get device user context
    device_id = data.person.get('deviceId')
    logger.info(f"Device ID from request: {device_id}")
    sf_user_id = None
    if device_id:
        user_context = get_device_user(device_id, db)
        logger.info(f"User context from device lookup: {user_context}")
        data.person["createdByUserId"] = user_context.get("sfUserId")
        sf_user_id = user_context.get("sfUserId")
        logger.info(f"Set createdByUserId to: {data.person.get('createdByUserId')}")
    else:
        logger.info("No device ID provided in request")
    
    """
    Creates/upserts a Salesforce Person Account with idempotency via UUID__c.
    Frontend expects: { localId, salesforceId }
    """
    try:
        # Check if Person Account already exists by UUID
        from ..salesforce.sf_client import query_soql
        
        existing_query = f"SELECT Id FROM Account WHERE UUID__c = '{data.localId}' LIMIT 1"
        existing = query_soql(existing_query)
        
        created_new = False
        if existing.get('records'):
            # Person Account exists, return existing ID
            sf_id = existing['records'][0]['Id']
            logger.info(f"Person Account already exists for UUID {data.localId}: {sf_id}")
        else:
            # Create new Person Account
            from ..salesforce.sf_client import create_person_account
            sf_id = create_person_account(data.person)
            logger.info(f"Created new Person Account for UUID {data.localId}: {sf_id}")
            created_new = True
        
        # Encounter creation now happens via /sync/Encounter after the person account call
        # to avoid duplicate ProgramEnrollmentService.ingestEncounter executions.
        # Any additional interaction logging should be handled by that dedicated endpoint.
        audit_logger.log_action(
            action_type="PERSON_ACCOUNT_CREATE" if created_new else "PERSON_ACCOUNT_SYNC",
            entity_id=data.localId or sf_id,
            details=f"Person account {'created' if created_new else 'synced'} via PWA",
            user_id=sf_user_id,
            event_type="MODIFY",
            status="Created" if created_new else "Synced",
            audit_json={
                "sfId": sf_id,
                "localId": data.localId,
                "created": created_new,
            },
        )

        return {"localId": data.localId, "salesforceId": sf_id}
    except Exception as e:
        logger.error(f"SF sync_person_account failed: {e}", exc_info=True)
        audit_logger.log_action(
            action_type="PERSON_ACCOUNT_SYNC",
            entity_id=data.localId,
            details="Person account sync failed.",
            user_id=sf_user_id,
            event_type="MODIFY",
            status="Failed",
            audit_json={"localId": data.localId, "error": str(e)},
        )
        raise HTTPException(status_code=500, detail={
            "message": "Failed to sync Person Account to Salesforce.",
            "error": str(e)
        })

@router.post('/sync/ProgramIntake')
def sync_program_intake(data: IntakePayload, db: Session = Depends(get_db)):
    
    # Get device user context
    device_id = data.intake.get('deviceId')
    sf_user_id = None
    if device_id:
        user_context = get_device_user(device_id, db)
        data.intake["createdByUserId"] = user_context.get("sfUserId")
        sf_user_id = user_context.get("sfUserId")
    
    """
    Creates a Program Enrollment (or equivalent) in Salesforce.
    Frontend only needs: { ok: true } on success.
    """
    try:
        if create_program_intake:
            create_program_intake(data.intake)
            audit_logger.log_action(
                action_type="PROGRAM_ENROLLMENT_SUBMIT",
                entity_id=data.localId or data.intake.get("personLocalId"),
                details=f"Program intake submitted for program {data.intake.get('programId')}",
                user_id=sf_user_id,
                event_type="MODIFY",
                status="Success",
                audit_json={
                    "localId": data.localId,
                    "programId": data.intake.get("programId"),
                },
            )
        else:
            logger.warning("Program intake creation function not configured; skipping Salesforce push.")
            audit_logger.log_action(
                action_type="PROGRAM_ENROLLMENT_SUBMIT",
                entity_id=data.localId or data.intake.get("personLocalId"),
                details="Program intake queued locally (no Salesforce integration configured).",
                user_id=sf_user_id,
                event_type="MODIFY",
                status="Skipped",
                audit_json={
                    "localId": data.localId,
                    "programId": data.intake.get("programId"),
                },
            )
    except Exception as e:
        logger.error(f"SF create_program_intake failed: {e}", exc_info=True)
        audit_logger.log_action(
            action_type="PROGRAM_ENROLLMENT_SUBMIT",
            entity_id=data.localId or data.intake.get("personLocalId"),
            details="Program intake failed to sync to Salesforce.",
            user_id=sf_user_id,
            event_type="MODIFY",
            status="Failed",
            audit_json={
                "localId": data.localId,
                "programId": data.intake.get("programId"),
                "error": str(e),
            },
        )
        raise HTTPException(status_code=500, detail={
            "message": "Failed to create Program Intake in Salesforce.",
            "error": str(e)
        })
    # For MVP/dev, succeed even without a live SF client
    return {"ok": True}

class EncounterPayload(BaseModel):
    encounterUuid: str
    personUuid: str
    firstName: str
    lastName: str
    pos: str = "27"
    isCrisis: bool = False
    notes: str = ""
    startUtc: str
    endUtc: str
    deviceId: Optional[str] = None  # Changed to Optional[str]

@router.post('/sync/Encounter')
def sync_encounter(data: EncounterPayload, db: Session = Depends(get_db)):
    """
    Creates full encounter with Program Enrollment, InteractionSummary, and Task
    with proper user context for all records.
    """
    try:
        # Get device user context
        user_context = {"userId": None, "sfUserId": None}
        if data.deviceId:
            user_context = get_device_user(data.deviceId, db)
        
        # Prepare encounter data with user context
        encounter_data = {
            "encounterUuid": data.encounterUuid,
            "personUuid": data.personUuid,
            "firstName": data.firstName,
            "lastName": data.lastName,
            "pos": data.pos,
            "isCrisis": data.isCrisis,
            "notes": data.notes,
            "startUtc": data.startUtc,
            "endUtc": data.endUtc,
            "createdByUserId": user_context.get("sfUserId")
        }
        
        from ..salesforce.sf_client import ingest_encounter
        result = ingest_encounter(encounter_data)
        
        audit_logger.log_action(
            action_type="ENCOUNTER_CREATE",
            entity_id=data.personUuid,
            details=f"Encounter created via PWA ({data.encounterUuid})",
            user_id=user_context.get("sfUserId"),
            event_type="MODIFY",
            status="Synced",
            audit_json={
                "encounterUuid": data.encounterUuid,
                "pos": data.pos,
                "isCrisis": data.isCrisis,
            },
        )

        logger.info(f"Successfully ingested encounter {data.encounterUuid}")
        return {"success": True, "result": result}
        
    except Exception as e:
        logger.error(f"Encounter ingestion failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail={
            "message": "Failed to ingest encounter.",
            "error": str(e)
        })
# Program Enrollments endpoint
@router.get('/person/{uuid}/enrollments')
def get_person_enrollments(uuid: str, request: Request):
    """Get Program Enrollments for a Person Account by UUID"""
    try:
        from ..salesforce.sf_client import query_soql
        
        # Query Person Account and related Program Enrollments
        soql = f"""
            SELECT Id, Name, 
                (SELECT Id, Name, Program__r.Name, Status__c, Start_Date__c, End_Date__c 
                 FROM Program_Enrollments__r 
                 ORDER BY Start_Date__c DESC)
            FROM Account 
            WHERE UUID__c = '{uuid}' 
            LIMIT 1
        """
        
        result = query_soql(soql)
        
        if not result.get('records'):
            raise HTTPException(status_code=404, detail="Person not found")
            
        person = result['records'][0]
        enrollments = person.get('Program_Enrollments__r', {}).get('records', [])
        
        response_payload = {
            "personId": person['Id'],
            "personName": person['Name'],
            "enrollments": enrollments
        }
        sf_user_id = request.headers.get("X-SF-User-Id") or request.query_params.get("sfUserId") or request.query_params.get("userId")
        source_ip = request.client.host if request.client else None
        audit_logger.log_action(
            action_type="VIEW_PERSON_ENROLLMENTS",
            entity_id=uuid or person.get('Id'),
            details=f"Viewed enrollments for {person.get('Name')}",
            user_id=sf_user_id,
            event_type="ACCESS",
            source_ip=source_ip,
             status="Success",
            audit_json={"enrollmentCount": len(enrollments)},
        )
        return response_payload
        
    except Exception as e:
        logger.error(f"Error getting enrollments for {uuid}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Add sync management endpoints
@router.get('/sync/status')
def get_sync_status():
    """Get current sync status and statistics"""
    try:
        runner = SyncRunner()
        return runner.get_sync_status()
    except Exception as e:
        logger.error(f"Error getting sync status: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post('/sync/run-full')
def run_full_sync():
    """Trigger a full sync from Salesforce"""
    try:
        runner = SyncRunner()
        result = runner.run_full_sync()
        return {"success": True, "counts": result}
    except Exception as e:
        logger.error(f"Full sync failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

class DeviceRegistration(BaseModel):
    deviceId: str
    userId: str
    sfUserId: str

@router.post('/register-device')
def register_device(data: DeviceRegistration, db: Session = Depends(get_db)):
    """Register a device with user context for proper CreatedBy tracking"""
    try:
        from ..models.db import get_db as get_sqlite_db
        sqlite_db = get_sqlite_db()
        
        # Create device_registrations table if it doesn't exist
        sqlite_db.execute("""
            CREATE TABLE IF NOT EXISTS device_registrations (
                device_id TEXT PRIMARY KEY,
                user_id TEXT,
                sf_user_id TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Insert or update device registration
        sqlite_db.execute("""
            INSERT OR REPLACE INTO device_registrations (device_id, user_id, sf_user_id)
            VALUES (?, ?, ?)
        """, (data.deviceId, data.userId, data.sfUserId))
        
        sqlite_db.commit()
        sqlite_db.close()
        
        logger.info(f"Registered device {data.deviceId} for user {data.sfUserId}")
        return {"success": True, "message": "Device registered successfully"}
        
    except Exception as e:
        logger.error(f"Device registration failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

sf_router = APIRouter(prefix="/sf", tags=["sf"])

@sf_router.get("/whoami")
def whoami():
    try:
        token, base = _get_token()
        j = _sf(_api("/limits"))
        return {"instance_url": base, "ok": True, "limits": list(j.keys())[:5]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@sf_router.get("/person-rt")
def person_rt():
    try:
        rid = get_person_account_record_type_id()
        return {"recordTypeId": rid}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
