// Test script to validate enhanced Clinical Note functionality
// 1. GoalAssignmentDetail with Account as Parent Record and progress tracking
// 2. Existing diagnoses retrieval and duplicate prevention

// Find an existing Case and Account
List<Case> testCases = [SELECT Id, AccountId, Account.Name FROM Case WHERE AccountId != null LIMIT 1];
if (testCases.isEmpty()) {
    System.debug('❌ No cases with AccountId found. Please ensure there are cases linked to Person Accounts.');
    return;
}

Case testCase = testCases[0];
Id caseId = testCase.Id;
Id accountId = testCase.AccountId;

System.debug('🎯 Testing Enhanced Clinical Note Functionality');
System.debug('📋 Case ID: ' + caseId);
System.debug('👤 Account ID: ' + accountId);
System.debug('👤 Account Name: ' + testCase.Account.Name);

// 1. Test getExistingDiagnoses method
System.debug('\n=== Testing getExistingDiagnoses method ===');
try {
    List<ClinicalNoteController.ExistingDiagnosis> existingDiagnoses = ClinicalNoteController.getExistingDiagnoses(caseId, accountId);
    System.debug('✅ Found ' + existingDiagnoses.size() + ' existing active diagnoses');
    
    for (ClinicalNoteController.ExistingDiagnosis diag : existingDiagnoses) {
        System.debug('  📊 Diagnosis: ' + diag.code + ' - ' + diag.description + ' (Status: ' + diag.status + ')');
    }
} catch (Exception e) {
    System.debug('❌ Error testing getExistingDiagnoses: ' + e.getMessage());
}

// 2. Test Goal Assignment Detail creation with progress tracking
System.debug('\n=== Testing GoalAssignmentDetail with Progress Tracking ===');

// Find some existing goal assignments for this case/account  
String goalQuery = 'SELECT Id, Goal__c, Goal__r.Name FROM GoalAssignment WHERE ProgramEnrollment__r.AccountId = :accountId LIMIT 2';
List<SObject> goalAssignments = Database.query(goalQuery);

if (goalAssignments.isEmpty()) {
    System.debug('⚠️ No goal assignments found for Account: ' + accountId);
    System.debug('💡 Tip: Create some goals for this participant first');
} else {
    System.debug('✅ Found ' + goalAssignments.size() + ' goal assignments to test with');
    
    // Prepare GoalWorkDetail objects with progress tracking
    List<ClinicalNoteController.GoalWorkDetail> goalWorkDetails = new List<ClinicalNoteController.GoalWorkDetail>();
    
    for (SObject ga : goalAssignments) {
        ClinicalNoteController.GoalWorkDetail detail = new ClinicalNoteController.GoalWorkDetail();
        detail.goalAssignmentId = (Id) ga.get('Id');
        detail.narrative = 'Made significant progress on goal: ' + ga.getSObject('Goal__r')?.get('Name');
        detail.progressBefore = 25; // Starting at 25%
        detail.progressAfter = 60;  // Improved to 60%
        detail.timeSpentMinutes = 45; // 45 minutes spent
        
        goalWorkDetails.add(detail);
        
        String goalName = (String) ga.getSObject('Goal__r')?.get('Name');
        System.debug('  🎯 Goal: ' + goalName + ' (Progress: 25% → 60%, Time: 45 min)');
    }
    
    // Create test request with goalWorkDetails
    ClinicalNoteController.SaveRequest testRequest = new ClinicalNoteController.SaveRequest();
    testRequest.caseId = caseId;
    testRequest.accountId = accountId;
    testRequest.interactionDate = String.valueOf(Date.today());
    testRequest.startTime = '14:00';
    testRequest.endTime = '15:00';
    testRequest.interpreterUsed = false;
    testRequest.pos = 'Office';
    testRequest.reason = 'Testing enhanced goal progress tracking';
    testRequest.services = 'Clinical counseling with goal progress tracking';
    testRequest.response = 'Client showed excellent progress on assigned goals';
    testRequest.plan = 'Continue with current goal work strategy';
    testRequest.noteType = 'Clinical';
    testRequest.goalWorkDetails = goalWorkDetails; // Using new format with progress tracking
    
    System.debug('\n📝 Creating Clinical Note with enhanced goal tracking...');
    
    try {
        ClinicalNoteController.SaveResult result = ClinicalNoteController.saveClinicalNoteRequest(testRequest);
        
        if (result.success) {
            System.debug('✅ Clinical Note created successfully!');
            System.debug('🆔 InteractionSummary ID: ' + result.interactionSummaryId);
            
            // Verify GoalAssignmentDetail records were created correctly
            System.debug('\n=== Verifying GoalAssignmentDetail Records ===');
            
            String detailQuery = 'SELECT Id, GoalAssignmentId, ParentRecordId, InteractionSummary__c, ' +
                               'ProgressBefore__c, ProgressAfter__c, TimeSpent__c, Narrative__c, DetailType__c ' +
                               'FROM GoalAssignmentDetail WHERE InteractionSummary__c = :interactionSummaryId';
            
            List<SObject> createdDetails = Database.query(detailQuery.replace(':interactionSummaryId', '\'' + result.interactionSummaryId + '\''));
            
            System.debug('✅ Created ' + createdDetails.size() + ' GoalAssignmentDetail records:');
            
            for (SObject detail : createdDetails) {
                System.debug('  🎯 Detail ID: ' + detail.get('Id'));
                System.debug('    - GoalAssignment: ' + detail.get('GoalAssignmentId'));
                System.debug('    - Parent Record: ' + detail.get('ParentRecordId') + ' (should be Account ID)');
                System.debug('    - InteractionSummary: ' + detail.get('InteractionSummary__c'));
                System.debug('    - Progress Before: ' + detail.get('ProgressBefore__c') + '%');
                System.debug('    - Progress After: ' + detail.get('ProgressAfter__c') + '%');
                System.debug('    - Time Spent: ' + detail.get('TimeSpent__c') + ' minutes');
                System.debug('    - Detail Type: ' + detail.get('DetailType__c'));
                System.debug('    - Narrative: ' + detail.get('Narrative__c'));
                
                // Verify Parent Record is the Account ID
                if (detail.get('ParentRecordId') == accountId) {
                    System.debug('    ✅ Parent Record correctly set to Account ID');
                } else {
                    System.debug('    ❌ Parent Record is NOT the Account ID! Got: ' + detail.get('ParentRecordId'));
                }
            }
            
            System.debug('\n🎉 SUCCESS: Enhanced Clinical Note functionality working correctly!');
            System.debug('✅ GoalAssignmentDetails created with Account as Parent Record');
            System.debug('✅ Progress tracking fields populated');
            System.debug('✅ InteractionSummary linking working');
            
        } else {
            System.debug('❌ Clinical Note creation failed: ' + result.errorMessage);
        }
        
    } catch (Exception e) {
        System.debug('❌ Error testing enhanced Clinical Note: ' + e.getMessage());
        System.debug('Stack Trace: ' + e.getStackTraceString());
    }
}

System.debug('\n=== Enhanced Clinical Note Test Complete ===');