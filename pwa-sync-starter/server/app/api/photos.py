# server/app/api/photos.py
"""
Photo upload and retrieval API for client photos.
Uploads photos to Salesforce as ContentVersion and updates Account.Photo__pc
Also retrieves emergency info (allergies, medications) for display.
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
import base64
import logging
from datetime import datetime

from ..salesforce.sf_client import _sf, _api, query_soql
from ..salesforce.audit_log_service import audit_logger

logger = logging.getLogger("photos")

router = APIRouter(prefix="/photos", tags=["photos"])


class PhotoUploadRequest(BaseModel):
    accountId: str
    imageData: str  # Base64 data URL (data:image/jpeg;base64,...)
    timestamp: str
    width: Optional[int] = None
    height: Optional[int] = None


class PhotoUploadResponse(BaseModel):
    success: bool
    contentDocumentId: Optional[str] = None
    photoUrl: Optional[str] = None
    message: str


class AccountPhotoInfo(BaseModel):
    accountId: str
    photoUrl: Optional[str] = None
    knownAllergies: Optional[str] = None
    currentMedications: Optional[str] = None
    medicationNotes: Optional[str] = None
    name: Optional[str] = None


def extract_base64_data(data_url: str) -> tuple[str, str]:
    """
    Extract base64 data and mime type from a data URL.
    Returns (base64_data, mime_type)
    """
    if data_url.startswith('data:'):
        # Format: data:image/jpeg;base64,/9j/4AAQSkZ...
        header, data = data_url.split(',', 1)
        mime_type = header.split(':')[1].split(';')[0]
        return data, mime_type
    # Assume it's already raw base64
    return data_url, 'image/jpeg'


def get_file_extension(mime_type: str) -> str:
    """Get file extension from mime type."""
    extensions = {
        'image/jpeg': 'jpg',
        'image/png': 'png',
        'image/gif': 'gif',
        'image/webp': 'webp',
    }
    return extensions.get(mime_type, 'jpg')


@router.post("/upload", response_model=PhotoUploadResponse)
async def upload_photo(request: PhotoUploadRequest):
    """
    Upload a photo for an Account (Person Account).
    
    1. Creates a ContentVersion with the photo
    2. Links it to the Account via ContentDocumentLink
    3. Updates the Account's Photo__pc field with an img tag
    
    The Photo__pc field is a rich text area that stores HTML,
    while PhotoUrl is a read-only system field.
    """
    try:
        logger.info(f"Uploading photo for account: {request.accountId}")
        
        # Extract base64 data
        base64_data, mime_type = extract_base64_data(request.imageData)
        extension = get_file_extension(mime_type)
        
        # Generate filename
        timestamp_str = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"ClientPhoto_{timestamp_str}.{extension}"
        
        # 1. Create ContentVersion
        content_version_data = {
            'Title': f'Client Photo - {timestamp_str}',
            'PathOnClient': filename,
            'VersionData': base64_data,
            'FirstPublishLocationId': request.accountId,
            'Description': f'Client photo uploaded via PWA on {request.timestamp}'
        }
        
        cv_result = _sf(_api("/sobjects/ContentVersion/"), method="POST", json=content_version_data)
        content_version_id = cv_result.get('id')
        
        if not content_version_id:
            raise HTTPException(status_code=500, detail="Failed to create ContentVersion")
        
        logger.info(f"Created ContentVersion: {content_version_id}")
        
        # 2. Get the ContentDocumentId from the ContentVersion
        cv_query = f"SELECT ContentDocumentId FROM ContentVersion WHERE Id = '{content_version_id}'"
        cv_result = query_soql(cv_query)
        
        if not cv_result.get('records'):
            raise HTTPException(status_code=500, detail="Failed to retrieve ContentDocumentId")
        
        content_document_id = cv_result['records'][0]['ContentDocumentId']
        logger.info(f"ContentDocumentId: {content_document_id}")
        
        # 3. Get the public download URL for the photo
        # We'll construct a reference URL that can be used in the Photo__pc field
        # Format: /sfc/servlet.shepherd/version/download/{ContentVersionId}
        download_url = f"/sfc/servlet.shepherd/version/download/{content_version_id}"
        
        # 4. Update Account's Photo__pc field with an HTML img tag
        # This is a rich text field, so we store HTML
        img_html = f'<img src="{download_url}" alt="Client Photo" style="max-width: 300px; max-height: 300px;" />'
        
        account_update = {
            'Photo__pc': img_html
        }
        
        _sf(_api(f"/sobjects/Account/{request.accountId}"), method="PATCH", json=account_update)
        logger.info(f"Updated Account Photo__pc for: {request.accountId}")
        
        # Log audit trail
        audit_logger.log_action(
            action_type="PHOTO_UPLOAD",
            entity_id=request.accountId,
            details=f"Client photo uploaded via PWA",
            event_type="MODIFY",
            status="Success",
            audit_json={
                "accountId": request.accountId,
                "contentVersionId": content_version_id,
                "contentDocumentId": content_document_id,
                "timestamp": request.timestamp,
            },
        )
        
        return PhotoUploadResponse(
            success=True,
            contentDocumentId=content_document_id,
            photoUrl=download_url,
            message="Photo uploaded successfully"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Photo upload failed: {e}", exc_info=True)
        
        audit_logger.log_action(
            action_type="PHOTO_UPLOAD",
            entity_id=request.accountId,
            details=f"Photo upload failed: {str(e)}",
            event_type="MODIFY",
            status="Failed",
            audit_json={
                "accountId": request.accountId,
                "error": str(e),
            },
        )
        
        raise HTTPException(status_code=500, detail=f"Photo upload failed: {str(e)}")


@router.get("/account/{account_id}", response_model=AccountPhotoInfo)
async def get_account_photo_and_emergency_info(account_id: str):
    """
    Get photo and emergency medical info for an Account.
    
    Returns:
    - photoUrl: URL to the client's photo
    - knownAllergies: Known allergies (CRITICAL for emergency)
    - currentMedications: Current medications being taken
    - medicationNotes: Additional medication notes
    - name: Client name for display
    """
    try:
        logger.info(f"Fetching photo and emergency info for account: {account_id}")
        
        # Query Account for photo and emergency fields
        query = f"""
            SELECT 
                Id,
                Name,
                PhotoUrl,
                Photo__pc,
                Known_Allergies__c,
                Currently_Taking_Medications__c,
                Medication_Notes__c
            FROM Account 
            WHERE Id = '{account_id}'
            LIMIT 1
        """
        
        result = query_soql(query)
        
        if not result.get('records'):
            raise HTTPException(status_code=404, detail="Account not found")
        
        record = result['records'][0]
        
        # Extract photo URL - prefer PhotoUrl (system), fallback to parsing Photo__pc
        photo_url = record.get('PhotoUrl')
        
        if not photo_url and record.get('Photo__pc'):
            # Try to extract src from the img tag in Photo__pc
            import re
            img_match = re.search(r'src="([^"]+)"', record.get('Photo__pc', ''))
            if img_match:
                photo_url = img_match.group(1)
        
        # Log PHI access for audit (allergies and medications are PHI)
        audit_logger.log_action(
            action_type="EMERGENCY_INFO_VIEW",
            entity_id=account_id,
            details="Emergency info (allergies/medications) viewed via PWA",
            event_type="VIEW",
            status="Success",
            audit_json={
                "accountId": account_id,
                "fieldsAccessed": ["Known_Allergies__c", "Currently_Taking_Medications__c", "Medication_Notes__c", "PhotoUrl"],
            },
        )
        
        return AccountPhotoInfo(
            accountId=account_id,
            photoUrl=photo_url,
            knownAllergies=record.get('Known_Allergies__c'),
            currentMedications=record.get('Currently_Taking_Medications__c'),
            medicationNotes=record.get('Medication_Notes__c'),
            name=record.get('Name'),
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to fetch account info: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to fetch account info: {str(e)}")
