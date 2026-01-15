@IsTest
private class ClinicalNoteControllerTest {

    @IsTest
    static void saveClinicalNoteRequiresCase() {
        // Test with empty request - should fail due to missing caseId
        ClinicalNoteController.SaveRequest request = new ClinicalNoteController.SaveRequest();
        // All fields are null by default
        
        ClinicalNoteController.SaveResult result = ClinicalNoteController.saveClinicalNoteRequest(request);
        
        System.assertEquals(false, result.success, 'Result should indicate failure when caseId is missing.');
        System.assertNotEquals(null, result.errorMessage, 'Error message should be populated.');
    }

    @IsTest
    static void saveClinicalNoteRequiresTimeFields() {
        // Test with caseId but missing time fields
        ClinicalNoteController.SaveRequest request = new ClinicalNoteController.SaveRequest();
        request.caseId = '500000000000001AAA'; // Fake Case ID (will fail in real org but tests validation logic)
        request.interactionDate = String.valueOf(Date.today());
        // Deliberately leaving startTime and endTime null
        
        ClinicalNoteController.SaveResult result = ClinicalNoteController.saveClinicalNoteRequest(request);
        
        System.assertEquals(false, result.success, 'Result should indicate failure when time fields are missing.');
        System.assert(result.errorMessage.containsIgnoreCase('time'), 'Error should mention time requirement.');
    }

    @IsTest
    static void deprecatedMethodStillWorks() {
        // Verify backward compatibility of deprecated method
        ClinicalNoteController.SaveResult result = ClinicalNoteController.saveClinicalNote(
            null, null, null, null, null, null, null, null, null, null, null, null, null, null
        );
        System.assertEquals(false, result.success, 'Deprecated method should still work.');
    }
}

