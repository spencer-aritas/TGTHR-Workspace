// Cleanup script for Case 4183 (500RT00000U4TTZYA3)
// Deletes today's InteractionSummaries and Diagnoses to "start fresh"

Id caseId = '500RT00000U4TTZYA3';
Id accountId = '001RT00000kJeiPYAS'; // From previous query
Date today = Date.today();

// 1. Find Interaction Summaries created today for this case
List<InteractionSummary> summaries = [
    SELECT Id, Name, CreatedDate 
    FROM InteractionSummary 
    WHERE RelatedRecordId = :caseId 
    AND DAY_ONLY(CreatedDate) = :today
];

System.debug('Found ' + summaries.size() + ' Interaction Summaries to delete.');

// 2. Find Diagnosis records created today for this client
List<Diagnosis__c> diagnoses = [
    SELECT Id, Name, Code__c 
    FROM Diagnosis__c 
    WHERE Client__c = :accountId 
    AND DAY_ONLY(CreatedDate) = :today
];

System.debug('Found ' + diagnoses.size() + ' Diagnoses to delete.');

Set<Id> summaryIds = new Set<Id>();
for(InteractionSummary s : summaries) {
    summaryIds.add(s.Id);
}

// 3. Find related GoalAssignmentDetails (if they aren't efficiently cascaded)
List<GoalAssignmentDetail> goalDetails = [
    SELECT Id 
    FROM GoalAssignmentDetail 
    WHERE InteractionSummary__c IN :summaryIds
];
System.debug('Found ' + goalDetails.size() + ' GoalAssignmentDetails to delete.');

// 4. Find related BenefitDisbursements
List<BenefitDisbursement> disbursements = [
    SELECT Id 
    FROM BenefitDisbursement 
    WHERE InteractionSummary__c IN :summaryIds
];
System.debug('Found ' + disbursements.size() + ' BenefitDisbursements to delete.');


// Execute deletions
if (!goalDetails.isEmpty()) {
    delete goalDetails;
    System.debug('Deleted GoalAssignmentDetails');
}

if (!disbursements.isEmpty()) {
    delete disbursements;
    System.debug('Deleted BenefitDisbursements');
}

if (!summaries.isEmpty()) {
    delete summaries;
    System.debug('Deleted InteractionSummaries');
}

if (!diagnoses.isEmpty()) {
    delete diagnoses;
    System.debug('Deleted Diagnoses');
}
