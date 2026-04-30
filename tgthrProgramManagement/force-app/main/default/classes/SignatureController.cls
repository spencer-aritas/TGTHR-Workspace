public with sharing class SignatureController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getUserSignature() {
        Map<String, Object> result = new Map<String, Object>();
        try {
            User currentUser = [
                SELECT Signature_Image_Id__c
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            String contentDocId = currentUser.Signature_Image_Id__c;

            if (String.isNotBlank(contentDocId)) {
                List<ContentVersion> versions = [
                    SELECT VersionData
                    FROM ContentVersion
                    WHERE ContentDocumentId = :contentDocId
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];

                if (!versions.isEmpty()) {
                    result.put('hasSignature', true);
                    result.put('signatureData', EncodingUtil.base64Encode(versions[0].VersionData));
                } else {
                    result.put('hasSignature', false);
                }
            } else {
                result.put('hasSignature', false);
            }
            result.put('success', true);
        } catch (Exception e) {
            result.put('success', false);
            result.put('hasSignature', false);
            result.put('error', e.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static Map<String, Object> saveUserSignature(String base64Data, String source) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            // Delete previous signature ContentDocument if one exists
            User currentUser = [
                SELECT Signature_Image_Id__c
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            Boolean isReplacement = String.isNotBlank(currentUser.Signature_Image_Id__c);
            if (isReplacement) {
                try {
                    delete [SELECT Id FROM ContentDocument WHERE Id = :currentUser.Signature_Image_Id__c LIMIT 1];
                } catch (Exception ignored) {
                    // Previous document may already be deleted
                }
            }

            ContentVersion cv = new ContentVersion();
            cv.Title = 'User_Signature_' + UserInfo.getUserId();
            cv.PathOnClient = 'user_signature.png';
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            insert cv;

            cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

            User u = new User(
                Id = UserInfo.getUserId(),
                Signature_Image_Id__c = cv.ContentDocumentId
            );
            update u;

            result.put('success', true);
            result.put('contentDocumentId', cv.ContentDocumentId);

            // Audit log
            String sourceLabel = String.isNotBlank(source) ? source : 'unknown';
            String action = isReplacement ? 'SIGNATURE_REPLACED' : 'SIGNATURE_SAVED';
            String details = action + ' via ' + sourceLabel
                + ' | ContentDocumentId: ' + cv.ContentDocumentId;
            logSignatureAudit(action, UserInfo.getUserId(), details);
        } catch (Exception e) {
            result.put('success', false);
            result.put('error', e.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static Map<String, Object> createContentVersion(String base64Data, String filename, String recordId, String signatureSource) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            ContentVersion cv = new ContentVersion();
            cv.Title = filename;
            cv.PathOnClient = filename;
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            cv.FirstPublishLocationId = recordId;
            
            insert cv;
            
            result.put('success', true);
            result.put('contentVersionId', cv.Id);

            // Audit log
            String sourceLabel = String.isNotBlank(signatureSource) ? signatureSource : 'draw';
            String details = 'SIGNATURE_APPLIED via ' + sourceLabel
                + ' | Record: ' + recordId
                + ' | ContentVersionId: ' + cv.Id
                + ' | File: ' + filename;
            logSignatureAudit('SIGNATURE_APPLIED', recordId, details);
            
        } catch (Exception e) {
            result.put('success', false);
            result.put('error', e.getMessage());
        }
        
        return result;
    }
    
    @AuraEnabled
    public static Map<String, Object> generateDocumentWithSignature(String recordId, String templateName, String objectName) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            // Call external doc gen service
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:DocGenService/generate-document');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            
            Map<String, Object> payload = new Map<String, Object>{
                'recordId' => recordId,
                'templatePath' => 'documents/' + templateName + '.docx',
                'objectName' => objectName
            };
            
            req.setBody(JSON.serialize(payload));
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                result.put('success', true);
                result.put('contentVersionId', responseData.get('contentVersionId'));
            } else {
                result.put('success', false);
                result.put('error', 'Document generation failed: ' + res.getBody());
            }
            
        } catch (Exception e) {
            result.put('success', false);
            result.put('error', e.getMessage());
        }
        
        return result;
    }

    private static void logSignatureAudit(String action, String entityId, String details) {
        try {
            AuditLogService.logAction(action, entityId, details, 'Signature');
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Signature audit log failed: ' + e.getMessage());
        }
    }
}