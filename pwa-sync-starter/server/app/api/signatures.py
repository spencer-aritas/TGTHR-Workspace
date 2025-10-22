from fastapi import APIRouter, File, UploadFile, Form, HTTPException
from app.salesforce.sf_client import get_sf_client
import base64

router = APIRouter()

@router.post("/signatures/upload")
async def upload_signature(
    file: UploadFile = File(...),
    recordId: str = Form(...),
    recordType: str = Form(...),
    timestamp: str = Form(...)
):
    try:
        # Read file content
        content = await file.read()
        
        # Get Salesforce client
        sf = get_sf_client()
        
        # Create ContentVersion
        content_version_data = {
            'Title': f'Signature_{timestamp}',
            'PathOnClient': f'signature_{timestamp}.png',
            'VersionData': base64.b64encode(content).decode('utf-8'),
            'FirstPublishLocationId': recordId
        }
        
        result = sf.ContentVersion.create(content_version_data)
        
        if not result['success']:
            raise HTTPException(status_code=400, detail="Failed to create ContentVersion")
        
        return {
            "success": True,
            "contentVersionId": result['id'],
            "message": "Signature uploaded successfully"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))