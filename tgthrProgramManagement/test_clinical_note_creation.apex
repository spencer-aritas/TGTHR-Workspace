System.debug('=== TESTING CLINICAL NOTE CREATION ===');

// Use the specified Case 3774
Id caseId = '500VY00000BI3yRYAT'; // Case 3774
System.debug('Using case: 3774 (' + caseId + ')');

// Get the Account from the Case
List<SObject> cases = Database.query('SELECT Id, CaseNumber, AccountId FROM Case WHERE Id = :caseId LIMIT 1');
if (cases.isEmpty()) {
    System.debug('❌ Case 3774 not found');
    return;
}
Id participantId = (Id)cases[0].get('AccountId');
System.debug('Using participant from case: ' + participantId);
// Find some benefits to select
List<SObject> benefits = Database.query('SELECT Id, Name FROM Benefit WHERE Name != null LIMIT 2');
if (benefits.isEmpty()) {
    System.debug('❌ No benefits found');
    return;
}
List<Id> benefitIds = new List<Id>();
for (SObject benefit : benefits) {
    benefitIds.add(benefit.Id);
    System.debug('Will use benefit: ' + benefit.get('Name') + ' (' + benefit.Id + ')');
}

// Find some goal assignments to select  
List<SObject> goalAssignments = Database.query('SELECT Id, Name, Goal_Name__c FROM GoalAssignment WHERE Name != null LIMIT 2');
if (goalAssignments.isEmpty()) {
    System.debug('⚠️ No goal assignments found');
}
List<Id> goalAssignmentIds = new List<Id>();
for (SObject goal : goalAssignments) {
    goalAssignmentIds.add(goal.Id);
    System.debug('Will use goal: ' + goal.get('Goal_Name__c') + ' (' + goal.Id + ')');
}

// Create a SaveRequest
ClinicalNoteController.SaveRequest request = new ClinicalNoteController.SaveRequest();
request.caseId = caseId;
request.accountId = participantId;
request.interactionDate = '2026-01-14';
request.startTime = '10:00';
request.endTime = '11:00';
request.interpreterUsed = false;
request.pos = null;
request.reason = 'Test clinical note for debugging';
request.services = 'Testing benefit and goal linking';
request.response = 'Patient engaged well';
request.plan = 'Continue current treatment plan';
request.goalAssignmentIds = goalAssignmentIds;
request.benefitIds = benefitIds;
request.noteType = 'Clinical';

System.debug('=== CALLING saveClinicalNoteRequest ===');
System.debug('Benefits to create: ' + request.benefitIds.size());
System.debug('Goals to create: ' + request.goalAssignmentIds.size());

ClinicalNoteController.SaveResult result = ClinicalNoteController.saveClinicalNoteRequest(request);

System.debug('=== SAVE RESULT ===');
System.debug('Success: ' + result.success);
if (result.success) {
    Id interactionSummaryId = result.interactionSummaryId;
    System.debug('InteractionSummary ID: ' + interactionSummaryId);
    
    // Check if GoalAssignmentDetails were created
    List<SObject> goalDetails = Database.query('SELECT Id, GoalAssignmentId, InteractionSummary__c, DetailType__c FROM GoalAssignmentDetail WHERE InteractionSummary__c = :interactionSummaryId');
    System.debug('✅ Created ' + goalDetails.size() + ' GoalAssignmentDetail records');
    
    // Check if BenefitDisbursements were created  
    List<SObject> disbursements = Database.query('SELECT Id, InteractionSummary__c, BenefitAssignmentId FROM BenefitDisbursement WHERE InteractionSummary__c = :interactionSummaryId');
    System.debug('✅ Created ' + disbursements.size() + ' BenefitDisbursement records');
    
    if (goalDetails.size() > 0 && disbursements.size() > 0) {
        System.debug('🎉 SUCCESS: Both goals and benefits were properly linked!');
    } else if (goalDetails.size() > 0) {
        System.debug('⚠️ PARTIAL SUCCESS: Goals linked but benefits missing');
    } else if (disbursements.size() > 0) {
        System.debug('⚠️ PARTIAL SUCCESS: Benefits linked but goals missing');
    } else {
        System.debug('❌ FAILURE: Neither goals nor benefits were linked');
    }
} else {
    System.debug('Error: ' + result.errorMessage);
}

System.debug('=== TEST COMPLETE ===');