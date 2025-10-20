public with sharing class TaskService {
    
    @AuraEnabled
    public static Id createFollowUpTask(String accountId, String encounterUuid, String notes, String pos, Boolean isCrisis, Datetime startUtc, Datetime endUtc) {
        // Check for existing task with same CallObject (encounterUuid)
        String existingQuery = 'SELECT Id FROM Task WHERE CallObject = :encounterUuid LIMIT 1';
        List<SObject> existingTasks = Database.query(existingQuery);
        if (!existingTasks.isEmpty()) {
            return (Id) existingTasks[0].get('Id');
        }
        
        SObject taskSObj = (SObject) Type.forName('Task').newInstance();
        taskSObj.put('Subject', 'Outreach Intake - Complete Medicaid Billing');
        taskSObj.put('WhatId', accountId);
        taskSObj.put('CallObject', encounterUuid);
        taskSObj.put('ActivityDate', Date.today());
        taskSObj.put('Status', 'Not Started');
        taskSObj.put('Priority', 'Normal');
        taskSObj.put('Description', 
            (notes != null ? notes + '\n' : '') +
            'POS: ' + (pos != null ? pos : '27') +
            ' | Crisis: ' + String.valueOf(isCrisis) +
            ' | Start: ' + String.valueOf(startUtc) +
            ' | End: ' + String.valueOf(endUtc)
        );
        
        insert taskSObj;
        return taskSObj.Id;
    }
}