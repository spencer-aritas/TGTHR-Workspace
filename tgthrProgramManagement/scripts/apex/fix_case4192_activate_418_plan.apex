// Fix Case 4192: force-activate the 4:18 Treatment Plan (a0qRT00000F2dpSYAR)
// which was fully signed but activation silently failed between deploys.
// Also stamps Is_Amendment__c = true since an active plan already existed.

Id interviewId = 'a0qRT00000F2dpSYAR'; // 4:18 PM plan
Id caseId      = '500RT00000ZcmYvYAJ'; // Case 4192

// Force-activate via the service (updates Case.Active_Treatment_Plan__c)
TreatmentPlanActivationService.ActivationResult result =
    TreatmentPlanActivationService.forceTreatmentPlanActivation(interviewId, caseId);

System.debug('Activated: ' + result.activated);
System.debug('Superseded: ' + result.superseded);

// Stamp Is_Amendment__c = true manually since forceTreatmentPlanActivation doesn't call stampAmendment
Map<String, Schema.SObjectField> ivFields =
    Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();
if (ivFields.containsKey('is_amendment__c')) {
    List<SObject> records = Database.query('SELECT Id FROM Interview__c WHERE Id = :interviewId LIMIT 1');
    if (!records.isEmpty()) {
        records[0].put('Is_Amendment__c', true);
        update records[0];
        System.debug('Is_Amendment__c stamped on 4:18 plan');
    }
}

// Verify
SObject updatedCase = Database.query('SELECT Active_Treatment_Plan__c FROM Case WHERE Id = :caseId LIMIT 1');
System.debug('Case.Active_Treatment_Plan__c is now: ' + updatedCase.get('Active_Treatment_Plan__c'));
System.debug('Expected: ' + interviewId);
System.debug('Match: ' + (updatedCase.get('Active_Treatment_Plan__c') == interviewId));
