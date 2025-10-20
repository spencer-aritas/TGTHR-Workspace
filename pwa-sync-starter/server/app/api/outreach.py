# server/app/api/outreach.py
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, validator
from typing import Dict, Any, Optional
from datetime import datetime
import uuid
import logging
import re
import json

from ..salesforce.sf_client import create_person_account
from ..db import DuckClient
from ..sync_runner import SyncRunner

logger = logging.getLogger("outreach")

router = APIRouter(tags=["outreach"])

class PersonAccountPayload(BaseModel):
    firstName: str
    lastName: str
    email: Optional[str] = None
    phone: Optional[str] = None
    birthdate: Optional[str] = None
    street: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    postalCode: Optional[str] = None
    genderIdentity: Optional[str] = None
    pronouns: Optional[str] = None
    hmisId: Optional[str] = None
    notes: Optional[str] = None
    createdBy: Optional[str] = None
    createdByEmail: Optional[str] = None
    deviceId: Optional[str] = None
    
    @validator('email')
    def validate_email(cls, v):
        if v and not re.match(r'^[\w\.-]+@[\w\.-]+\.\w+$', v):
            raise ValueError('Invalid email format')
        return v
    
    @validator('phone')
    def validate_phone(cls, v):
        if v:
            # Remove non-digits and validate length
            digits = re.sub(r'\D', '', v)
            if len(digits) < 10 or len(digits) > 15:
                raise ValueError('Invalid phone number')
        return v
    
    @validator('firstName', 'lastName')
    def validate_names(cls, v):
        if not v or len(v.strip()) < 1:
            raise ValueError('Name is required')
        if len(v) > 100:
            raise ValueError('Name too long')
        return v.strip()
    
    @validator('notes')
    def validate_notes(cls, v):
        if v and len(v) > 5000:
            raise ValueError('Notes too long')
        return v

class OutreachEncounterPayload(BaseModel):
    personLocalId: str
    encounterDate: str
    location: str
    notes: str
    services: Optional[str] = None
    followUpNeeded: bool = False
    deviceId: str

@router.post('/quick-person-account')
async def create_quick_person_account(payload: PersonAccountPayload):
    """Create a Person Account for outreach encounters"""
    try:
        local_id = str(uuid.uuid4())
        
        # Store locally first
        db = DuckClient()
        try:
            # Add created_by fields to participants table
            db.execute("""
                CREATE TABLE IF NOT EXISTS participants (
                    uuid VARCHAR PRIMARY KEY,
                    sfid VARCHAR,
                    first_name VARCHAR,
                    last_name VARCHAR,
                    email VARCHAR,
                    phone VARCHAR,
                    date_of_birth DATE,
                    created_by VARCHAR,
                    created_by_email VARCHAR,
                    device_id VARCHAR,
                    updated_at TIMESTAMP
                )
            """)
            
            db.execute("""
                INSERT OR REPLACE INTO participants 
                (uuid, first_name, last_name, email, phone, date_of_birth, created_by, created_by_email, device_id, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                local_id,
                payload.firstName,
                payload.lastName, 
                payload.email,
                payload.phone,
                payload.birthdate,
                payload.createdBy,
                payload.createdByEmail,
                payload.deviceId,
                datetime.now().isoformat()
            ))
        finally:
            db.close()
        
        # Try to sync to Salesforce if online
        try:
            person_data = payload.dict()
            person_data["uuid"] = local_id
            sf_id = create_person_account(person_data)
            
            # Update with Salesforce ID
            db = DuckClient()
            try:
                db.execute("UPDATE participants SET sfid = ? WHERE uuid = ?", (sf_id, local_id))
            finally:
                db.close()
                
            return {"localId": local_id, "salesforceId": sf_id, "synced": True}
            
        except Exception as e:
            logger.warning(f"Failed to sync to Salesforce, stored locally: {e}")
            return {"localId": local_id, "synced": False}
            
    except Exception as e:
        logger.error(f"Failed to create person account: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post('/outreach-intake')
async def submit_outreach_encounter(payload: OutreachEncounterPayload):
    """Submit an outreach encounter - syncs to Salesforce ProgramEnrollmentService"""
    try:
        encounter_id = str(uuid.uuid4())
        
        # Store encounter locally first
        db = DuckClient()
        try:
            db.execute("""
                CREATE TABLE IF NOT EXISTS outreach_encounters (
                    id VARCHAR PRIMARY KEY,
                    person_uuid VARCHAR NOT NULL,
                    encounter_date VARCHAR NOT NULL,
                    location VARCHAR,
                    notes TEXT,
                    services VARCHAR,
                    follow_up_needed BOOLEAN DEFAULT FALSE,
                    device_id VARCHAR,
                    synced BOOLEAN DEFAULT FALSE,
                    created_at TIMESTAMP DEFAULT now()
                )
            """)
            
            db.execute("""
                INSERT INTO outreach_encounters 
                (id, person_uuid, encounter_date, location, notes, services, follow_up_needed, device_id)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                encounter_id,
                payload.personLocalId,
                payload.encounterDate,
                payload.location,
                payload.notes,
                payload.services,
                payload.followUpNeeded,
                payload.deviceId
            ))
        finally:
            db.close()
        
        # Try to sync to Salesforce ProgramEnrollmentService if online
        try:
            from ..salesforce.sf_client import ingest_encounter
            
            # Call Apex class ProgramEnrollmentService.ingestEncounter
            apex_payload = {
                "encounterUuid": encounter_id,
                "personUuid": payload.personLocalId,
                "firstName": "Unknown",  # Will be updated from person data
                "lastName": "Unknown",   # Will be updated from person data
                "startUtc": payload.encounterDate,
                "endUtc": payload.encounterDate,
                "pos": "27",  # Default POS
                "isCrisis": payload.followUpNeeded,
                "notes": payload.notes
            }
            
            result = ingest_encounter(apex_payload)
            
            # Mark as synced
            db = DuckClient()
            try:
                db.execute("UPDATE outreach_encounters SET synced = TRUE WHERE id = ?", (encounter_id,))
            finally:
                db.close()
                
            return {"encounterId": encounter_id, "status": "synced", "taskId": result.get("taskId")}
            
        except Exception as e:
            logger.warning(f"Failed to sync to Salesforce, stored locally: {e}")
            return {"encounterId": encounter_id, "status": "stored"}
        
    except Exception as e:
        logger.error(f"Failed to submit outreach encounter: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get('/outreach/sync-status')
async def get_outreach_sync_status():
    """Get sync status for outreach data"""
    try:
        db = DuckClient()
        try:
            # Count unsynced records - handle table not existing
            try:
                unsynced_people = db.fetch_all("SELECT COUNT(*) as count FROM participants WHERE sfid IS NULL")
                unsynced_people_count = unsynced_people[0]["count"] if unsynced_people else 0
            except:
                unsynced_people_count = 0
                
            try:
                unsynced_encounters = db.fetch_all("SELECT COUNT(*) as count FROM outreach_encounters WHERE synced = FALSE")
                unsynced_encounters_count = unsynced_encounters[0]["count"] if unsynced_encounters else 0
            except:
                unsynced_encounters_count = 0
            
            return {
                "unsyncedPeople": unsynced_people_count,
                "unsyncedEncounters": unsynced_encounters_count,
                "lastSyncTime": db.fetch_all("SELECT value FROM meta WHERE key = 'last_sync_time'")[0]["value"] if db.fetch_all("SELECT value FROM meta WHERE key = 'last_sync_time'") else None
            }
        finally:
            db.close()
    except Exception as e:
        logger.error(f"Failed to get sync status: {e}")
        return {"unsyncedPeople": 0, "unsyncedEncounters": 0, "lastSyncTime": None}

@router.post('/outreach/sync')
async def sync_outreach_data():
    """Sync pending outreach data to Salesforce"""
    try:
        runner = SyncRunner()
        result = runner.run_full_sync()
        return {"success": True, "result": result}
    except Exception as e:
        logger.error(f"Sync failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post('/new-client-intake')
async def create_new_client_intake(payload: dict):
    """Create comprehensive new client intake with all related records"""
    try:
        intake_id = str(uuid.uuid4())
        
        # Store intake locally first
        db = DuckClient()
        try:
            db.execute("""
                CREATE TABLE IF NOT EXISTS new_client_intakes (
                    id VARCHAR PRIMARY KEY,
                    encounter_uuid VARCHAR NOT NULL,
                    person_uuid VARCHAR NOT NULL,
                    payload TEXT NOT NULL,
                    synced BOOLEAN DEFAULT FALSE,
                    created_at TIMESTAMP DEFAULT now()
                )
            """)
            
            db.execute("""
                INSERT INTO new_client_intakes 
                (id, encounter_uuid, person_uuid, payload)
                VALUES (?, ?, ?, ?)
            """, (
                intake_id,
                payload['encounterUuid'],
                payload['personUuid'],
                json.dumps(payload)
            ))
        finally:
            db.close()
        
        # Try to sync to Salesforce if online
        try:
            from ..salesforce.intake_service import process_full_intake
            
            result = process_full_intake(payload)
            
            # Mark as synced
            db = DuckClient()
            try:
                db.execute("UPDATE new_client_intakes SET synced = TRUE WHERE id = ?", (intake_id,))
            finally:
                db.close()
                
            return {
                "success": True,
                "encounterId": payload['encounterUuid'],
                "personAccountId": result.get('personAccountId'),
                "programEnrollmentId": result.get('programEnrollmentId'),
                "benefitAssignmentIds": result.get('benefitAssignmentIds', []),
                "interactionSummaryId": result.get('interactionSummaryId'),
                "taskId": result.get('taskId'),
                "synced": True
            }
            
        except Exception as e:
            logger.warning(f"Failed to sync to Salesforce, stored locally: {e}")
            return {
                "success": True,
                "encounterId": payload['encounterUuid'],
                "synced": False,
                "errors": [str(e)]
            }
        
    except Exception as e:
        logger.error(f"Failed to create new client intake: {e}")
        raise HTTPException(status_code=500, detail=str(e))