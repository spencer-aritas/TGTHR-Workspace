# server/app/api/sync.py
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing import List, Literal, Dict, Any
from ..models.db import SessionLocal
from ..schema import Note, Meta
from ..salesforce.sf_client import _get_token, _api, _sf, get_person_account_record_type_id, create_person_account
from ..sync_runner import SyncRunner
import uuid
import logging

logger = logging.getLogger("sync")

router = APIRouter()
create_program_intake = None  # TODO: Placeholder for create_program_intake function
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
                n.enrolleeId = m.payload.get('enrolleeId')
                n.body = m.payload.get('body','')
                n.createdAt = m.payload.get('createdAt')
                n.updatedAt = m.payload.get('updatedAt')
                n.deviceId = m.payload.get('deviceId')
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
    from datetime import datetime
    data.person["uuid"] = data.localId
    
    # Get device user context
    device_id = data.person.get('deviceId')
    logger.info(f"Device ID from request: {device_id}")
    if device_id:
        user_context = get_device_user(device_id, db)
        logger.info(f"User context from device lookup: {user_context}")
        data.person["createdByUserId"] = user_context.get("sfUserId")
        logger.info(f"Set createdByUserId to: {data.person.get('createdByUserId')}")
    else:
        logger.info("No device ID provided in request")
    
    """
    Creates/upserts a Salesforce Person Account with idempotency via UUID__c.
    Frontend expects: { localId, salesforceId }
    """
    try:
        # Check if Person Account already exists by UUID
        from ..salesforce.sf_client import query_soql, upsert_person_by_uuid
        
        existing_query = f"SELECT Id FROM Account WHERE UUID__c = '{data.localId}' LIMIT 1"
        existing = query_soql(existing_query)
        
        if existing.get('records'):
            # Person Account exists, return existing ID
            sf_id = existing['records'][0]['Id']
            logger.info(f"Person Account already exists for UUID {data.localId}: {sf_id}")
        else:
            # Create new Person Account
            from ..salesforce.sf_client import create_person_account
            sf_id = create_person_account(data.person)
            logger.info(f"Created new Person Account for UUID {data.localId}: {sf_id}")
        
        # Create full encounter with all downstream records (Program Enrollment, InteractionSummary, Task, Benefit Assignments)
        notes = data.person.get('notes') or 'Initial outreach contact'
        try:
            from ..salesforce.sf_client import ingest_encounter
            import uuid as uuid_lib
            encounter_uuid = str(uuid_lib.uuid4())
            
            # Create full encounter with defaults for Street Outreach
            encounter_payload = {
                "encounterUuid": encounter_uuid,
                "personUuid": data.localId,
                "firstName": data.person.get('firstName', 'Unknown'),
                "lastName": data.person.get('lastName', 'Unknown'),
                "startUtc": datetime.now().isoformat(),
                "endUtc": datetime.now().isoformat(),
                "pos": "27",  # Default POS - Outreach Site / Street
                "isCrisis": False,
                "notes": notes,
                "createdByUserId": data.person.get('createdByUserId')
            }
            
            logger.info(f"Creating full encounter for Person Account {sf_id}")
            result = ingest_encounter(encounter_payload)
            logger.info(f"Created full encounter {encounter_uuid}: {result}")
            
        except Exception as e:
            logger.warning(f"Failed to create full encounter: {e}")
            # Fall back to just creating InteractionSummary
            try:
                from ..salesforce.sf_client import call_interaction_summary_service
                import uuid as uuid_lib
                interaction_uuid = str(uuid_lib.uuid4())
                
                interaction_id = call_interaction_summary_service(
                    account_id=sf_id,
                    notes=notes,
                    uuid=interaction_uuid,
                    created_by_user_id=data.person.get('createdByUserId')
                )
                logger.info(f"Created fallback InteractionSummary {interaction_id} for Account {sf_id}")
            except Exception as e2:
                logger.warning(f"Failed to create InteractionSummary fallback: {e2}")
            
        return {"localId": data.localId, "salesforceId": sf_id}
    except Exception as e:
        logger.error(f"SF sync_person_account failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail={
            "message": "Failed to sync Person Account to Salesforce.",
            "error": str(e)
        })

@router.post('/sync/ProgramIntake')
def sync_program_intake(data: IntakePayload, db: Session = Depends(get_db)):
    
    # Get device user context
    device_id = data.intake.get('deviceId')
    if device_id:
        user_context = get_device_user(device_id, db)
        data.intake["createdByUserId"] = user_context.get("sfUserId")
    
    """
    Creates a Program Enrollment (or equivalent) in Salesforce.
    Frontend only needs: { ok: true } on success.
    """
    try:
        create_program_intake(data.intake)
    except Exception as e:
        logger.error(f"SF create_program_intake failed: {e}", exc_info=True)
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
    deviceId: str = None

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
def get_person_enrollments(uuid: str):
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
        
        return {
            "personId": person['Id'],
            "personName": person['Name'],
            "enrollments": enrollments
        }
        
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