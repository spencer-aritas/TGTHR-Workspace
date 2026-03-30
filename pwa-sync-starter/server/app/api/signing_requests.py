# server/app/api/signing_requests.py
import logging
import uuid
import base64
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

logger = logging.getLogger("signing_requests_api")
router = APIRouter()


# ── Request / response models ───────────────────────────────────

class CreateSigningRequest(BaseModel):
    targetRecordId: str
    targetRecordType: str
    caseId: Optional[str] = None
    interactionId: Optional[str] = None
    interviewId: Optional[str] = None
    requestedByUserId: str
    requestedForUserId: str
    requestedForRole: Optional[str] = None


class CompleteSigningRequest(BaseModel):
    deviceAttestationAccepted: bool
    signatureDataURL: str


# ── In-process store (swap for DB / Salesforce custom object later) ──

_signing_requests: dict = {}


# ── Endpoints ────────────────────────────────────────────────────

@router.post("/signing-requests")
async def create_signing_request(body: CreateSigningRequest):
    """Issue a new signing request and write an initial audit record."""
    try:
        from ..salesforce.audit_log_service import audit_logger

        request_id = str(uuid.uuid4())
        now = datetime.now(timezone.utc).isoformat()

        record = {
            "requestId": request_id,
            "targetRecordId": body.targetRecordId,
            "targetRecordType": body.targetRecordType,
            "caseId": body.caseId,
            "interactionId": body.interactionId,
            "interviewId": body.interviewId,
            "requestedByUserId": body.requestedByUserId,
            "requestedForUserId": body.requestedForUserId,
            "requestedForRole": body.requestedForRole,
            "status": "Pending",
            "requestedAt": now,
            "openedAt": None,
            "signedAt": None,
            "deviceAttestationAccepted": False,
            "signatureContentVersionId": None,
            "auditEntityId": None,
        }

        _signing_requests[request_id] = record

        # Write initial audit entry
        audit_logger.log_action(
            action_type="SIGNATURE_REQUEST_CREATED",
            entity_id=body.targetRecordId,
            details=f"Signing request {request_id} created for user {body.requestedForUserId}",
            user_id=body.requestedByUserId,
            event_type="CREATE",
            audit_json={
                "requestId": request_id,
                "targetRecordId": body.targetRecordId,
                "targetRecordType": body.targetRecordType,
                "requestedForUserId": body.requestedForUserId,
                "requestedForRole": body.requestedForRole,
            },
        )

        logger.info(f"Created signing request {request_id}")
        return record

    except Exception as e:
        logger.error(f"Failed to create signing request: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/signing-requests/{requestId}")
async def get_signing_request(requestId: str):
    """Retrieve a signing request by id."""
    record = _signing_requests.get(requestId)
    if not record:
        raise HTTPException(status_code=404, detail="Signing request not found")
    return record


@router.post("/signing-requests/{requestId}/open")
async def open_signing_request(requestId: str):
    """Record that the assignee opened the signing request."""
    record = _signing_requests.get(requestId)
    if not record:
        raise HTTPException(status_code=404, detail="Signing request not found")

    if record["status"] not in ("Pending",):
        raise HTTPException(status_code=400, detail=f"Cannot open request in status {record['status']}")

    record["status"] = "Opened"
    record["openedAt"] = datetime.now(timezone.utc).isoformat()
    return record


@router.post("/signing-requests/{requestId}/complete")
async def complete_signing_request(requestId: str, body: CompleteSigningRequest):
    """
    Validate attestation, upload signature, write audit, and close the request.
    Steps performed atomically on the server:
    1. Validate request is in an open/pending state
    2. Validate device attestation was accepted
    3. Create ContentVersion in Salesforce
    4. Update signing request state
    5. Write audit log
    """
    record = _signing_requests.get(requestId)
    if not record:
        raise HTTPException(status_code=404, detail="Signing request not found")

    if record["status"] not in ("Pending", "Opened"):
        raise HTTPException(status_code=400, detail=f"Cannot complete request in status {record['status']}")

    if not body.deviceAttestationAccepted:
        raise HTTPException(status_code=422, detail="Device attestation must be accepted before signing")

    try:
        from ..salesforce.sf_client import _sf, _api
        from ..salesforce.audit_log_service import audit_logger

        now = datetime.now(timezone.utc).isoformat()

        # 1. Decode dataURL and upload as ContentVersion
        content_version_id = None
        try:
            # dataURL format: data:image/png;base64,iVBOR...
            header, b64data = body.signatureDataURL.split(",", 1)
            content_version_data = {
                "Title": f"Signature_{requestId}",
                "PathOnClient": f"signature_{requestId}.png",
                "VersionData": b64data,
                "FirstPublishLocationId": record["targetRecordId"],
            }
            result = _sf(_api("/sobjects/ContentVersion/"), method="POST", json=content_version_data)
            content_version_id = result.get("id")
        except Exception as upload_err:
            logger.error(f"Signature upload failed for request {requestId}: {upload_err}", exc_info=True)
            raise HTTPException(status_code=500, detail="Signature upload failed")

        # 2. Update the signing request
        record["status"] = "Signed"
        record["signedAt"] = now
        record["deviceAttestationAccepted"] = True
        record["signatureContentVersionId"] = content_version_id

        # 3. Audit trail
        audit_logger.log_action(
            action_type="SIGNATURE_COMPLETED",
            entity_id=record["targetRecordId"],
            details=f"Signing request {requestId} completed by user {record['requestedForUserId']}",
            user_id=record["requestedForUserId"],
            event_type="MODIFY",
            audit_json={
                "requestId": requestId,
                "signatureContentVersionId": content_version_id,
                "targetRecordId": record["targetRecordId"],
                "targetRecordType": record["targetRecordType"],
                "requestedByUserId": record["requestedByUserId"],
                "requestedForUserId": record["requestedForUserId"],
                "requestedForRole": record.get("requestedForRole"),
                "deviceAttestationAccepted": True,
                "signedAt": now,
            },
        )

        logger.info(f"Signing request {requestId} completed. ContentVersion={content_version_id}")
        return record

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to complete signing request {requestId}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
