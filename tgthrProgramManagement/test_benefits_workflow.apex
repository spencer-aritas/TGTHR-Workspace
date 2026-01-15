// Test creating a Clinical Note with Benefits selected
// This demonstrates the complete InteractionSummary -> BenefitDisbursement -> Services Provided workflow

// Setup test data
Id accountId = '001VY00000CGQ5rYAH';  // Amanda Arellano
Id caseId = null; // We'll create or find one
List<String> benefitIds = new List<String>{'0jiRT0000000Sd1YAE'}; // Mental Health Support

// Find or create a Case for this Account
List<SObject> cases = Database.query('SELECT Id FROM Case WHERE AccountId = :accountId LIMIT 1');
if (cases.isEmpty()) {
    SObject newCase = Schema.getGlobalDescribe().get('Case').newSObject();
    newCase.put('AccountId', accountId);
    newCase.put('Subject', 'Clinical Note Test Case');
    newCase.put('Status', 'Open');
    Database.insert(newCase);
    caseId = newCase.Id;
    System.debug('Created new Case: ' + caseId);
} else {
    caseId = cases[0].Id;
    System.debug('Using existing Case: ' + caseId);
}

// Create InteractionSummary record first (to simulate UI creation)
SObject interaction = Schema.getGlobalDescribe().get('InteractionSummary').newSObject();
interaction.put('Name', 'Clinical Note Test - ' + DateTime.now().format('yyyy-MM-dd HH:mm'));
interaction.put('AccountId', accountId);
interaction.put('Date_of_Interaction__c', Date.today());
interaction.put('MeetingNotes', 'Test Clinical Note with Mental Health Support benefit - this should show up in Services Provided section');
interaction.put('InteractionPurpose', 'Clinical');
interaction.put('RelatedRecordId', caseId);
Database.insert(interaction);
Id interactionId = interaction.Id;
System.debug('Created InteractionSummary: ' + interactionId);

// Now create BenefitDisbursements for the selected benefits using the same logic as ClinicalNoteController
Id programId = null;
String enrollmentStatus = null;

// Get Program from Case → Account → ProgramEnrollment (following ClinicalNoteController logic)
String enrollmentQuery = 'SELECT Id, ProgramId, Status FROM ProgramEnrollment WHERE ContactId IN (SELECT PersonContactId FROM Account WHERE Id = :accountId) AND Status IN (\'Enrolled\', \'Active\') ORDER BY CreatedDate DESC LIMIT 1';
List<SObject> enrollments = Database.query(enrollmentQuery);
if (!enrollments.isEmpty()) {
    programId = (Id) enrollments[0].get('ProgramId');
    enrollmentStatus = String.valueOf(enrollments[0].get('Status'));
    System.debug('Found Program: ' + programId + ', Status: ' + enrollmentStatus);
}

if (programId != null && (enrollmentStatus == 'Enrolled' || enrollmentStatus == 'Active')) {
    // Create disbursements for each selected benefit (following ClinicalNoteController.createBenefitDisbursements)
    for (String benefitId : benefitIds) {
        System.debug('Processing benefit: ' + benefitId);
        List<String> participantIds = new List<String>{ String.valueOf(accountId) };
        
        // Step 1: Check if BenefitAssignment exists
        BenefitDisbursementService.BenefitAssignmentCheckResult checkResult = 
            BenefitDisbursementService.checkBenefitAssignmentsWithParams(
                participantIds,
                benefitId
            );
        
        System.debug('Assignment check result: ' + checkResult);
        
        // Step 2: Create missing BenefitAssignments if needed
        if (!checkResult.allParticipantsReady) {
            System.debug('Creating missing BenefitAssignment for benefit: ' + benefitId);
            Map<String, Boolean> assignmentResults = 
                BenefitDisbursementService.createMissingBenefitAssignments(
                    participantIds,
                    benefitId,
                    String.valueOf(programId),
                    null // programName
                );
            System.debug('Assignment creation results: ' + assignmentResults);
        }
        
        // Step 3: Create BenefitDisbursements
        List<BenefitDisbursementService.DisburseResult> results = 
            BenefitDisbursementService.createDisbursementsWithParamsExt(
                participantIds,
                benefitId,
                String.valueOf(programId),
                null, // programName
                String.valueOf(Date.today()),
                1, // quantity
                'Created from Clinical Note Test', // notes
                null, // startDateTime
                null, // endDateTime
                null, // caseNotes
                null, // eventType
                null, // individualCaseNotesByParticipant
                true // isClinical
            );
        
        System.debug('Disbursement results: ' + results);
        for (BenefitDisbursementService.DisburseResult result : results) {
            if (result.success) {
                System.debug('✓ Successfully created disbursement: ' + result.disbursementId);
            } else {
                System.debug('✗ Failed: ' + result.message);
            }
        }
    }
    
    System.debug('🎯 InteractionSummary created with Benefits: ' + interactionId);
    System.debug('Now test document generation with this InteractionSummary ID: ' + interactionId);
} else {
    System.debug('❌ No active ProgramEnrollment found or invalid status: ' + enrollmentStatus);
}