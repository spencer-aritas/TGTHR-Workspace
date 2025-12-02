/**
 * Backfill Script: Create InterviewDocument__c records for existing Interview__c records
 * 
 * This script:
 * 1. Queries Interview__c records without UUID__c
 * 2. Generates UUID__c for each
 * 3. Creates InterviewDocument__c index records for chart viewer
 * 
 * Run via: sfdx force:apex:execute -f scripts/apex/backfillInterviewDocuments.apex
 */

// Target Case ID - change this to the Case you want to backfill
String caseId = '500RT00000U4TTZYA3';

// Query Interview__c records for this case
String interviewQuery = 
    'SELECT Id, Name, Case__c, Interaction_Summary__c, InterviewTemplateVersion__r.InterviewTemplate__c, ' +
    'UUID__c, Completed_On__c, Client_Signed__c, Staff_Signed__c, ' +
    'Date_Client_Signed__c, Date_Staff_Signed__c ' +
    'FROM Interview__c ' +
    'WHERE Case__c = :caseId';

List<SObject> interviews = Database.query(interviewQuery);

System.debug('Found ' + interviews.size() + ' interviews to process');

// Lists for DML
List<SObject> interviewsToUpdate = new List<SObject>();
List<SObject> interviewDocsToInsert = new List<SObject>();

for (SObject interview : interviews) {
    // Generate UUID if missing
    String uuid = (String) interview.get('UUID__c');
    if (String.isBlank(uuid)) {
        uuid = EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 32);
        interview.put('UUID__c', uuid);
        interviewsToUpdate.add(interview);
    }
    
    // Create InterviewDocument__c record
    SObject interviewDoc = Schema.getGlobalDescribe().get('InterviewDocument__c').newSObject();
    interviewDoc.put('Interview__c', interview.get('Id'));
    interviewDoc.put('Case__c', interview.get('Case__c'));
    
    if (interview.get('Interaction_Summary__c') != null) {
        interviewDoc.put('Interaction_Summary__c', interview.get('Interaction_Summary__c'));
    }
    
    SObject templateVersion = interview.getSObject('InterviewTemplateVersion__r');
    if (templateVersion != null && templateVersion.get('InterviewTemplate__c') != null) {
        interviewDoc.put('InterviewTemplate__c', templateVersion.get('InterviewTemplate__c'));
    }
    
    // Set document status based on signature status
    Boolean clientSigned = (Boolean) interview.get('Client_Signed__c');
    Boolean staffSigned = (Boolean) interview.get('Staff_Signed__c');
    
    if (clientSigned == true || staffSigned == true) {
        interviewDoc.put('Document_Status__c', 'Final');
    } else if (interview.get('Completed_On__c') != null) {
        interviewDoc.put('Document_Status__c', 'Final');
    } else {
        interviewDoc.put('Document_Status__c', 'Draft');
    }
    
    // Default to Stateless rendering mode
    interviewDoc.put('Rendering_Mode__c', 'Stateless');
    
    interviewDocsToInsert.add(interviewDoc);
}

// Update Interview__c records with UUIDs
if (!interviewsToUpdate.isEmpty()) {
    update interviewsToUpdate;
    System.debug('Updated ' + interviewsToUpdate.size() + ' Interview records with UUIDs');
}

// Insert InterviewDocument__c records
if (!interviewDocsToInsert.isEmpty()) {
    Database.SaveResult[] results = Database.insert(interviewDocsToInsert, false);
    
    Integer successCount = 0;
    Integer failCount = 0;
    
    for (Database.SaveResult result : results) {
        if (result.isSuccess()) {
            successCount++;
        } else {
            failCount++;
            for (Database.Error err : result.getErrors()) {
                System.debug('Error: ' + err.getMessage());
            }
        }
    }
    
    System.debug('Created ' + successCount + ' InterviewDocument records');
    System.debug('Failed: ' + failCount);
}

System.debug('Backfill complete!');
