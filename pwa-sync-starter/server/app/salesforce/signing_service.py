# server/app/salesforce/signing_service.py
"""Service for querying and completing co-signatures (CM/PS/Manager) from the PWA."""
import logging
from typing import Dict, Any, List
from datetime import datetime
from .sf_client import SalesforceClient

logger = logging.getLogger("signing_service")


class SigningService:
    def __init__(self):
        self.sf_client = SalesforceClient()

    def get_pending_signatures(self, user_id: str) -> List[Dict[str, Any]]:
        """Return Interview__c records where the current user is assigned as
        CaseManager, PeerSupport, or Manager approver and has not yet signed."""
        try:
            logger.info(f"Fetching pending signatures for user {user_id}")

            # Also check delegated approvers for manager queue
            delegate_result = self.sf_client.query(
                "SELECT Id FROM User "
                "WHERE DelegatedApproverId = :userId AND IsActive = true",
                {"userId": user_id},
            )
            delegating_ids = [r["Id"] for r in delegate_result.get("records", [])]
            all_approver_ids = [user_id] + delegating_ids

            # Build IN clause
            ids_csv = ", ".join(f"'{uid}'" for uid in all_approver_ids)

            query = f"""
            SELECT Id, Name, Status__c, Started_On__c,
                   Case__c, Case__r.CaseNumber, Case__r.Contact.Name,
                   InterviewTemplateVersion__r.InterviewTemplate__r.Name,
                   Staff_Signed__c, Client_Signed__c,
                   CaseManager_Signed_By__c, CaseManager_Signed_By__r.Name,
                   CaseManager_Signed__c, Date_CaseManager_Signed__c,
                   PeerSupport_Signed_By__c, PeerSupport_Signed_By__r.Name,
                   PeerSupport_Signed__c, Date_PeerSupport_Signed__c,
                   Requires_Manager_Approval__c, Manager_Approver__c,
                   Manager_Approver__r.Name, Manager_Signed__c
            FROM Interview__c
            WHERE Status__c NOT IN ('Voided', 'Signed')
              AND (
                (CaseManager_Signed_By__c = '{user_id}'
                 AND (CaseManager_Signed__c = false OR CaseManager_Signed__c = null))
                OR
                (PeerSupport_Signed_By__c = '{user_id}'
                 AND (PeerSupport_Signed__c = false OR PeerSupport_Signed__c = null))
                OR
                (Requires_Manager_Approval__c = true
                 AND Manager_Approver__c IN ({ids_csv})
                 AND (Manager_Signed__c = false OR Manager_Signed__c = null)
                 AND (CaseManager_Signed_By__c = null OR CaseManager_Signed__c = true)
                 AND (PeerSupport_Signed_By__c = null OR PeerSupport_Signed__c = true))
              )
            ORDER BY Started_On__c DESC
            LIMIT 50
            """

            result = self.sf_client.query(query)
            items = []
            for r in result.get("records", []):
                template_name = (
                    ((r.get("InterviewTemplateVersion__r") or {})
                     .get("InterviewTemplate__r") or {})
                    .get("Name")
                )
                case_number = (r.get("Case__r") or {}).get("CaseNumber")
                client_name = ((r.get("Case__r") or {}).get("Contact") or {}).get("Name")

                # Determine which roles the user can sign for
                roles: List[str] = []
                cm_by = r.get("CaseManager_Signed_By__c")
                ps_by = r.get("PeerSupport_Signed_By__c")
                mgr_by = r.get("Manager_Approver__c")

                if cm_by == user_id and not r.get("CaseManager_Signed__c"):
                    roles.append("CaseManager")
                if ps_by == user_id and not r.get("PeerSupport_Signed__c"):
                    roles.append("PeerSupport")
                if (
                    r.get("Requires_Manager_Approval__c")
                    and mgr_by in all_approver_ids
                    and not r.get("Manager_Signed__c")
                    # Manager can only sign after CM/PS are done
                    and (cm_by is None or r.get("CaseManager_Signed__c"))
                    and (ps_by is None or r.get("PeerSupport_Signed__c"))
                ):
                    roles.append("Manager")

                if not roles:
                    continue

                items.append({
                    "interviewId": r.get("Id"),
                    "interviewName": r.get("Name"),
                    "templateName": template_name,
                    "status": r.get("Status__c"),
                    "startedOn": r.get("Started_On__c"),
                    "caseId": r.get("Case__c"),
                    "caseNumber": case_number,
                    "clientName": client_name,
                    "pendingRoles": roles,
                    "caseManagerName": (r.get("CaseManager_Signed_By__r") or {}).get("Name"),
                    "peerSupportName": (r.get("PeerSupport_Signed_By__r") or {}).get("Name"),
                    "managerName": (r.get("Manager_Approver__r") or {}).get("Name"),
                })

            logger.info(f"Found {len(items)} pending signatures for user {user_id}")
            return items
        except Exception as e:
            logger.error(f"Failed to fetch pending signatures for {user_id}: {e}", exc_info=True)
            raise

    def cosign_interview(
        self,
        interview_id: str,
        user_id: str,
        role: str,
        signature_data_url: str = None,
    ) -> Dict[str, Any]:
        """Complete a co-signature on an Interview__c record.

        role must be one of: CaseManager, PeerSupport, Manager
        """
        try:
            logger.info(f"Co-sign interview {interview_id} as {role} by user {user_id}")

            # Fetch current state
            rec = self.sf_client.query(
                "SELECT Id, CaseManager_Signed_By__c, CaseManager_Signed__c, "
                "PeerSupport_Signed_By__c, PeerSupport_Signed__c, "
                "Requires_Manager_Approval__c, Manager_Approver__c, Manager_Signed__c, "
                "Status__c "
                "FROM Interview__c WHERE Id = :interviewId LIMIT 1",
                {"interviewId": interview_id},
            ).get("records", [])

            if not rec:
                raise ValueError("Interview not found")
            rec = rec[0]

            now_iso = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000+0000")
            update_data: Dict[str, Any] = {}

            # Upload signature image first if provided
            content_doc_id = None
            if signature_data_url:
                content_doc_id = self._upload_signature(interview_id, user_id, role, signature_data_url)

            if role == "CaseManager":
                if rec.get("CaseManager_Signed_By__c") != user_id:
                    raise PermissionError("User is not assigned as Case Manager signer")
                if rec.get("CaseManager_Signed__c"):
                    return {"success": True, "message": "Already signed as Case Manager"}
                update_data["CaseManager_Signed__c"] = True
                update_data["Date_CaseManager_Signed__c"] = now_iso
                if content_doc_id:
                    update_data["CaseManager_Signature_File_Id__c"] = content_doc_id

            elif role == "PeerSupport":
                if rec.get("PeerSupport_Signed_By__c") != user_id:
                    raise PermissionError("User is not assigned as Peer Support signer")
                if rec.get("PeerSupport_Signed__c"):
                    return {"success": True, "message": "Already signed as Peer Support"}
                update_data["PeerSupport_Signed__c"] = True
                update_data["Date_PeerSupport_Signed__c"] = now_iso
                if content_doc_id:
                    update_data["PeerSupport_Signature_File_Id__c"] = content_doc_id

            elif role == "Manager":
                if rec.get("Manager_Approver__c") != user_id:
                    # Check delegation
                    delegate_result = self.sf_client.query(
                        "SELECT Id FROM User "
                        "WHERE DelegatedApproverId = :userId AND IsActive = true",
                        {"userId": user_id},
                    )
                    delegating_ids = [r["Id"] for r in delegate_result.get("records", [])]
                    if rec.get("Manager_Approver__c") not in delegating_ids:
                        raise PermissionError("User is not the assigned manager approver")
                if rec.get("Manager_Signed__c"):
                    return {"success": True, "message": "Already signed as Manager"}
                update_data["Manager_Signed__c"] = True
                update_data["Manager_Signed_Date__c"] = now_iso
            else:
                raise ValueError(f"Invalid role: {role}")

            self.sf_client.update("Interview__c", interview_id, update_data)

            # Check if all signatures are now complete → advance status
            self._maybe_advance_status(interview_id)

            logger.info(f"Co-sign complete: {interview_id} / {role} by {user_id}")
            return {"success": True, "message": f"Signed as {role}"}

        except (ValueError, PermissionError):
            raise
        except Exception as e:
            logger.error(f"Co-sign failed for {interview_id}: {e}", exc_info=True)
            raise

    def _maybe_advance_status(self, interview_id: str):
        """If all required signatures are collected, advance to Submitted."""
        try:
            rec = self.sf_client.query(
                "SELECT Id, Status__c, Staff_Signed__c, Client_Signed__c, "
                "CaseManager_Signed_By__c, CaseManager_Signed__c, "
                "PeerSupport_Signed_By__c, PeerSupport_Signed__c, "
                "Requires_Manager_Approval__c, Manager_Signed__c "
                "FROM Interview__c WHERE Id = :interviewId LIMIT 1",
                {"interviewId": interview_id},
            ).get("records", [])
            if not rec:
                return
            r = rec[0]

            cm_done = r.get("CaseManager_Signed_By__c") is None or r.get("CaseManager_Signed__c")
            ps_done = r.get("PeerSupport_Signed_By__c") is None or r.get("PeerSupport_Signed__c")
            mgr_done = not r.get("Requires_Manager_Approval__c") or r.get("Manager_Signed__c")

            if cm_done and ps_done and mgr_done and r.get("Status__c") != "Submitted":
                self.sf_client.update("Interview__c", interview_id, {"Status__c": "Submitted"})
                logger.info(f"All signatures collected, advanced {interview_id} to Submitted")
        except Exception as e:
            logger.warning(f"Could not advance interview status {interview_id}: {e}")

    def _upload_signature(self, record_id: str, user_id: str, role: str, data_url: str) -> str:
        """Upload signature data URL as ContentVersion, return ContentDocumentId."""
        import base64

        if "," in data_url:
            body_b64 = data_url.split(",", 1)[1]
        else:
            body_b64 = data_url

        cv_result = self.sf_client.create("ContentVersion", {
            "Title": f"{role}_Signature_{record_id}",
            "PathOnClient": f"{role.lower()}_signature.png",
            "VersionData": body_b64,
            "Description": f"{role} signature by {user_id}",
        })
        cv_id = cv_result.get("id")
        if not cv_id:
            raise RuntimeError("Failed to create ContentVersion")

        doc_result = self.sf_client.query(
            "SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cvId LIMIT 1",
            {"cvId": cv_id},
        )
        doc_records = doc_result.get("records", [])
        if not doc_records:
            raise RuntimeError("ContentVersion created but no ContentDocumentId found")

        content_doc_id = doc_records[0]["ContentDocumentId"]

        # Link to the Interview record
        self.sf_client.create("ContentDocumentLink", {
            "ContentDocumentId": content_doc_id,
            "LinkedEntityId": record_id,
            "ShareType": "V",
        })

        return content_doc_id
