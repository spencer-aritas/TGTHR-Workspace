/**
 * CaseFormDocumentController
 *
 * Backend for the caseFormDocumentHub LWC.
 * Manages ROI, Consent Form, and Disclosure Form documents attached to a Case.
 * Each record stores metadata (agency, date, type) alongside the Salesforce
 * ContentDocument ID of the uploaded file.
 */
public with sharing class CaseFormDocumentController {

    // ─── DTO ─────────────────────────────────────────────────────────────────

    public class FormDocumentDTO {
        @AuraEnabled public Id     id;
        @AuraEnabled public String name;
        @AuraEnabled public String formType;
        @AuraEnabled public Id     agencyId;
        @AuraEnabled public String agencyName;
        @AuraEnabled public String documentDate;   // ISO date string YYYY-MM-DD
        @AuraEnabled public String consentType;
        @AuraEnabled public String contentDocumentId;
        @AuraEnabled public String title;          // ContentDocument.Title
        @AuraEnabled public Boolean hasFile;
        @AuraEnabled public Boolean fileDisabled;  // inverse of hasFile, for datatable column
    }

    // ─── Public API ──────────────────────────────────────────────────────────

    /**
     * Return the Case's linked Account (participant/client) for use as the
     * default "Agency or Individual" value.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getCaseClient(Id caseId) {
        try {
            List<Case> cases = [
                SELECT Id, AccountId, Account.Name
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
            if (!cases.isEmpty() && cases[0].AccountId != null) {
                return new Map<String, String>{
                    'id'   => cases[0].AccountId,
                    'name' => cases[0].Account.Name
                };
            }
        } catch (Exception e) {
            System.debug('CaseFormDocumentController.getCaseClient error: ' + e.getMessage());
        }
        return null;
    }

    /**
     * Return all form documents for a Case.
     * If formType is provided, results are filtered to that type.
     */
    @AuraEnabled(cacheable=true)
    public static List<FormDocumentDTO> getDocuments(Id caseId, String formType) {
        try {
            List<CaseFormDocument__c> records;
            if (String.isBlank(formType)) {
                records = [
                    SELECT Id, Name, Form_Type__c,
                           Agency_Individual__c, Agency_Individual__r.Name,
                           Document_Date__c, Consent_Type__c,
                           ContentDocumentId__c
                    FROM CaseFormDocument__c
                    WHERE Case__c = :caseId
                    ORDER BY Document_Date__c DESC NULLS LAST, CreatedDate DESC
                ];
            } else {
                records = [
                    SELECT Id, Name, Form_Type__c,
                           Agency_Individual__c, Agency_Individual__r.Name,
                           Document_Date__c, Consent_Type__c,
                           ContentDocumentId__c
                    FROM CaseFormDocument__c
                    WHERE Case__c = :caseId
                      AND Form_Type__c = :formType
                    ORDER BY Document_Date__c DESC NULLS LAST, CreatedDate DESC
                ];
            }

            // Bulk-fetch ContentDocument titles
            Set<Id> contentDocIds = new Set<Id>();
            for (CaseFormDocument__c rec : records) {
                if (String.isNotBlank(rec.ContentDocumentId__c)) {
                    try { contentDocIds.add((Id) rec.ContentDocumentId__c); } catch (Exception ex) {}
                }
            }

            Map<Id, String> titleMap = new Map<Id, String>();
            if (!contentDocIds.isEmpty()) {
                for (ContentDocument cd : [SELECT Id, Title FROM ContentDocument WHERE Id IN :contentDocIds]) {
                    titleMap.put(cd.Id, cd.Title);
                }
            }

            List<FormDocumentDTO> result = new List<FormDocumentDTO>();
            for (CaseFormDocument__c rec : records) {
                FormDocumentDTO dto = new FormDocumentDTO();
                dto.id              = rec.Id;
                dto.name            = rec.Name;
                dto.formType        = rec.Form_Type__c;
                dto.agencyId        = rec.Agency_Individual__c;
                dto.agencyName      = rec.Agency_Individual__r != null ? rec.Agency_Individual__r.Name : '';
                dto.documentDate    = rec.Document_Date__c != null ? String.valueOf(rec.Document_Date__c) : null;
                dto.consentType     = rec.Consent_Type__c;
                dto.contentDocumentId = rec.ContentDocumentId__c;
                dto.hasFile         = String.isNotBlank(rec.ContentDocumentId__c);
                dto.fileDisabled    = !dto.hasFile;

                if (dto.hasFile && titleMap.containsKey((Id) rec.ContentDocumentId__c)) {
                    dto.title = titleMap.get((Id) rec.ContentDocumentId__c);
                } else {
                    dto.title = rec.Name;
                }

                result.add(dto);
            }
            return result;

        } catch (Exception e) {
            throw new AuraHandledException('Failed to load documents: ' + e.getMessage());
        }
    }

    /**
     * Create a new CaseFormDocument__c record linking metadata to an uploaded file.
     *
     * @param caseId              Case record ID
    * @param formType            'ROI', 'Consent Form', or 'Disclosure Form'
    * @param agencyId            Optional account lookup metadata
     * @param docDate             Effective date of the form
    * @param consentType         Subtype text (required for ROI and Consent Form)
     * @param contentDocumentId   ContentDocument ID of the uploaded file
     * @return ID of the created CaseFormDocument__c record
     */
    @AuraEnabled
    public static Id saveFormDocument(
        Id     caseId,
        String formType,
        Id     agencyId,
        Date   docDate,
        String consentType,
        String contentDocumentId
    ) {
        // Server-side validation
        if (caseId == null)          throw new AuraHandledException('Case ID is required.');
        if (String.isBlank(formType)) throw new AuraHandledException('Form Type is required.');
        if (docDate == null)          throw new AuraHandledException('Date is required.');

        if ((formType == 'ROI' || formType == 'Consent Form') && String.isBlank(consentType)) {
            throw new AuraHandledException('Subtype is required for ' + formType + '.');
        }
        if (String.isBlank(contentDocumentId)) {
            throw new AuraHandledException('Please upload a document file before saving.');
        }

        try {
            CaseFormDocument__c rec = new CaseFormDocument__c(
                Case__c          = caseId,
                Form_Type__c     = formType,
                Document_Date__c = docDate,
                ContentDocumentId__c = contentDocumentId
            );
            if (agencyId != null)               rec.Agency_Individual__c = agencyId;
            if (String.isNotBlank(consentType)) rec.Consent_Type__c = consentType;

            insert rec;

            // Also link the ContentDocument to this metadata record so it appears
            // in both Case Files and the form document record.
            if (String.isNotBlank(contentDocumentId)) {
                try {
                    ContentDocumentLink cdl = new ContentDocumentLink(
                        ContentDocumentId = (Id) contentDocumentId,
                        LinkedEntityId    = rec.Id,
                        ShareType         = 'V',
                        Visibility        = 'AllUsers'
                    );
                    insert cdl;
                } catch (Exception linkEx) {
                    // Non-fatal — document is still linked to Case
                    System.debug('CaseFormDocumentController: CDL link to CaseFormDocument failed (non-fatal): ' + linkEx.getMessage());
                }
            }

            return rec.Id;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to save document: ' + e.getMessage());
        }
    }

    /**
     * Delete a CaseFormDocument__c metadata record.
     * Does NOT delete the underlying ContentDocument / file.
     */
    @AuraEnabled
    public static void deleteFormDocument(Id recordId) {
        try {
            CaseFormDocument__c rec = [SELECT Id FROM CaseFormDocument__c WHERE Id = :recordId LIMIT 1];
            delete rec;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to delete record: ' + e.getMessage());
        }
    }
}
