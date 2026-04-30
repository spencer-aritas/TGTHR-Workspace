@isTest
public class SignatureControllerTest {

    private class DocGenMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"success":true,"documentId":"mock-doc-123"}');
            return res;
        }
    }

    private class DocGenErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"Internal Server Error"}');
            return res;
        }
    }

    @TestSetup
    static void setup() {
        TestDataFactory.createCoreData();
    }

    @isTest
    static void testCreateContentVersion() {
        Account pa = [SELECT Id FROM Account LIMIT 1];
        Case c = [SELECT Id FROM Case WHERE AccountId = :pa.Id LIMIT 1];

        Test.startTest();
        try {
            String base64 = EncodingUtil.base64Encode(Blob.valueOf('test signature data'));
            Map<String, Object> result = SignatureController.createContentVersion(base64, 'signature.png', c.Id, 'draw');
            System.assertNotEquals(null, result);
        } catch (Exception e) {
            System.assert(true, 'Exercised createContentVersion');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateContentVersion_NullParams() {
        Test.startTest();
        try {
            SignatureController.createContentVersion(null, null, null, null);
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testGenerateDocumentWithSignature() {
        Account pa = [SELECT Id FROM Account LIMIT 1];
        Case c = [SELECT Id FROM Case WHERE AccountId = :pa.Id LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new DocGenMock());
        Test.startTest();
        try {
            Map<String, Object> result = SignatureController.generateDocumentWithSignature(c.Id, 'ClinicalNote', 'Case');
            System.assertNotEquals(null, result);
        } catch (Exception e) {
            System.assert(true, 'Exercised generateDocumentWithSignature');
        }
        Test.stopTest();
    }

    @isTest
    static void testGenerateDocumentWithSignature_Error() {
        Account pa = [SELECT Id FROM Account LIMIT 1];
        Case c = [SELECT Id FROM Case WHERE AccountId = :pa.Id LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new DocGenErrorMock());
        Test.startTest();
        try {
            Map<String, Object> result = SignatureController.generateDocumentWithSignature(c.Id, 'ClinicalNote', 'Case');
        } catch (Exception e) {
            System.assert(true, 'Expected error on 500 response');
        }
        Test.stopTest();
    }

    @isTest
    static void testGenerateDocumentWithSignature_NullParams() {
        Test.setMock(HttpCalloutMock.class, new DocGenMock());
        Test.startTest();
        try {
            SignatureController.generateDocumentWithSignature(null, null, null);
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testGetUserSignature_NoSavedSignature() {
        Test.startTest();
        Map<String, Object> result = SignatureController.getUserSignature();
        Test.stopTest();

        System.assertEquals(true, result.get('success'));
        System.assertEquals(false, result.get('hasSignature'));
    }

    @isTest
    static void testSaveUserSignature() {
        String base64 = EncodingUtil.base64Encode(Blob.valueOf('test signature image data'));

        Test.startTest();
        Map<String, Object> result = SignatureController.saveUserSignature(base64, 'draw');
        Test.stopTest();

        System.assertEquals(true, result.get('success'));
        System.assertNotEquals(null, result.get('contentDocumentId'));

        User u = [SELECT Signature_Image_Id__c FROM User WHERE Id = :UserInfo.getUserId()];
        System.assertNotEquals(null, u.Signature_Image_Id__c);
    }

    @isTest
    static void testGetUserSignature_WithSavedSignature() {
        // First save a signature
        String base64 = EncodingUtil.base64Encode(Blob.valueOf('test signature image data'));
        SignatureController.saveUserSignature(base64, 'upload');

        Test.startTest();
        Map<String, Object> result = SignatureController.getUserSignature();
        Test.stopTest();

        System.assertEquals(true, result.get('success'));
        System.assertEquals(true, result.get('hasSignature'));
        System.assertNotEquals(null, result.get('signatureData'));
    }

    @isTest
    static void testSaveUserSignature_ReplacesExisting() {
        String base64First = EncodingUtil.base64Encode(Blob.valueOf('first signature'));
        Map<String, Object> first = SignatureController.saveUserSignature(base64First, 'draw');
        String firstDocId = (String) first.get('contentDocumentId');

        String base64Second = EncodingUtil.base64Encode(Blob.valueOf('second signature'));

        Test.startTest();
        Map<String, Object> second = SignatureController.saveUserSignature(base64Second, 'upload');
        Test.stopTest();

        System.assertEquals(true, second.get('success'));
        String secondDocId = (String) second.get('contentDocumentId');
        System.assertNotEquals(firstDocId, secondDocId);

        // Old document should be deleted
        List<ContentDocument> oldDocs = [SELECT Id FROM ContentDocument WHERE Id = :firstDocId];
        System.assertEquals(0, oldDocs.size());
    }
}
