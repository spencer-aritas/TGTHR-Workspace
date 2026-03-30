/**
 * Data fix for Case 4192 — Treatment Plan 3/2/2026
 *
 * Problem: The plan a0qRT00000F8R7FYAV has all signatures collected and
 * Requires_Manager_Approval__c = false, but Status__c is stuck at "Submitted"
 * and Case.Active_Treatment_Plan__c still points to the previous plan.
 *
 * Fix:
 *   1. Set Interview Status__c = 'Signed'
 *   2. Set Is_Amendment__c = true (an active plan existed when this one was created)
 *   3. Activate on the Case (Active_Treatment_Plan__c = this interview)
 */

Id newPlanId = 'a0qRT00000F8R7FYAV';
Id caseId    = '500RT00000ZcmYvYAJ';

// --- 1. Fix the Interview record ---
List<SObject> plans = Database.query(
    'SELECT Id, Status__c, Is_Amendment__c FROM Interview__c WHERE Id = :newPlanId LIMIT 1'
);
if (!plans.isEmpty()) {
    plans[0].put('Status__c',      'Signed');
    plans[0].put('Is_Amendment__c', true);
    update plans[0];
    System.debug('✅ Interview updated: Status=Signed, Is_Amendment=true');
} else {
    System.debug('❌ Interview not found!');
}

// --- 2. Activate on the Case ---
List<SObject> caseRecords = Database.query(
    'SELECT Id, Active_Treatment_Plan__c FROM Case WHERE Id = :caseId LIMIT 1'
);
if (!caseRecords.isEmpty()) {
    caseRecords[0].put('Active_Treatment_Plan__c', newPlanId);
    update caseRecords[0];
    System.debug('✅ Case.Active_Treatment_Plan__c → ' + newPlanId);
} else {
    System.debug('❌ Case not found!');
}
