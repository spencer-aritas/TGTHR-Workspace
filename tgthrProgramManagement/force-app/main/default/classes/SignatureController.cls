public with sharing class SignatureController {
    
    @AuraEnabled
    public static Map<String, Object> createContentVersion(String base64Data, String filename, String recordId) {
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
}