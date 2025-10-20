from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from datetime import datetime
from ..models.db import get_db

router = APIRouter(prefix="/api/device", tags=["device"])

class DeviceRegistration(BaseModel):
    deviceId: str
    userId: str
    sfUserId: str

@router.post("/register")
async def register_device(registration: DeviceRegistration):
    """Register device with user for offline-first usage"""
    db = get_db()
    
    try:
        # Upsert device registration
        db.execute("""
            INSERT OR REPLACE INTO device_registrations 
            (device_id, user_id, sf_user_id, registered_at, last_sync_at)
            VALUES (?, ?, ?, ?, ?)
        """, (
            registration.deviceId,
            registration.userId, 
            registration.sfUserId,
            datetime.utcnow().isoformat(),
            datetime.utcnow().isoformat()
        ))
        db.commit()
        
        return {"success": True, "message": "Device registered successfully"}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Registration failed: {str(e)}")

@router.get("/user/{device_id}")
async def get_device_user(device_id: str):
    """Get user info for registered device"""
    db = get_db()
    
    result = db.execute("""
        SELECT user_id, sf_user_id FROM device_registrations 
        WHERE device_id = ?
    """, (device_id,)).fetchone()
    
    if not result:
        raise HTTPException(status_code=404, detail="Device not registered")
        
    return {
        "userId": result[0],
        "sfUserId": result[1]
    }