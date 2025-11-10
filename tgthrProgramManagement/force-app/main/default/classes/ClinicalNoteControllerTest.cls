@IsTest
private class ClinicalNoteControllerTest {

    @IsTest
    static void saveClinicalNoteRequiresCase() {
        ClinicalNoteController.SaveResult result = ClinicalNoteController.saveClinicalNote(
            null, // caseId
            null, // interactionDateStr
            null, // startTimeStr
            null, // endTimeStr  
            null, // interpreterUsed
            null, // pos
            null, // reason
            null, // services
            null, // response
            null, // plan
            null, // goalAssignmentIds
            null, // codeAssignmentIds
            null  // benefitIds
        );
        System.assertEquals(false, result.success, 'Result should indicate failure when request is missing.');
        System.assertNotEquals(null, result.errorMessage, 'Error message should be populated.');
    }
}

