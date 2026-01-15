System.debug('=== DEBUGGING INTERACTION SUMMARY 8BVRT0000007erx4AA ===');

// Check if InteractionSummary exists
List<SObject> interactions = Database.query('SELECT Id, Name, AccountId, Description_of_Services__c FROM InteractionSummary WHERE Id = \'8BVRT0000007erx4AA\'');
System.debug('Found ' + interactions.size() + ' InteractionSummary records');
for (SObject interaction : interactions) {
    System.debug('InteractionSummary: ' + interaction.get('Name') + ' | Account: ' + interaction.get('AccountId'));
    System.debug('Description_of_Services__c: ' + interaction.get('Description_of_Services__c'));
}

if (interactions.isEmpty()) {
    System.debug('❌ InteractionSummary 8BVRT0000007erx4AA does NOT exist!');
    return;
}

String accountId = (String) interactions[0].get('AccountId');

// Check for GoalAssignmentDetails linked to this interaction
System.debug('=== CHECKING GOALS ===');
List<SObject> goalDetails = Database.query('SELECT Id, Name, GoalAssignmentId, InteractionSummary__c, GoalAssignment.Goal_Name__c FROM GoalAssignmentDetail WHERE InteractionSummary__c = \'8BVRT0000007erx4AA\'');
System.debug('Found ' + goalDetails.size() + ' GoalAssignmentDetail records linked to this InteractionSummary');
for (SObject detail : goalDetails) {
    SObject goalAssignment = (SObject) detail.getSObject('GoalAssignment');
    String goalName = goalAssignment != null ? (String) goalAssignment.get('Goal_Name__c') : 'Unknown';
    System.debug('  - GoalAssignmentDetail: ' + detail.get('Name') + ' | Goal: ' + goalName);
}

// Check for BenefitDisbursements linked to this interaction  
System.debug('=== CHECKING BENEFITS ===');
List<SObject> disbursements = Database.query('SELECT Id, Name, InteractionSummary__c, BenefitAssignmentId, BenefitAssignment.Benefit.Name FROM BenefitDisbursement WHERE InteractionSummary__c = \'8BVRT0000007erx4AA\'');
System.debug('Found ' + disbursements.size() + ' BenefitDisbursement records linked to this InteractionSummary');
for (SObject disbursement : disbursements) {
    SObject benefitAssignment = (SObject) disbursement.getSObject('BenefitAssignment');
    SObject benefit = benefitAssignment != null ? (SObject) benefitAssignment.getSObject('Benefit') : null;
    String benefitName = benefit != null ? (String) benefit.get('Name') : 'Unknown';
    System.debug('  - BenefitDisbursement: ' + disbursement.get('Name') + ' | Benefit: ' + benefitName);
}

// Check if there are ANY GoalAssignmentDetails or BenefitDisbursements for this Account
System.debug('=== CHECKING ACCOUNT TOTALS ===');
if (!String.isBlank(accountId)) {
    try {
        List<SObject> accountBenefits = Database.query('SELECT Id FROM BenefitDisbursement LIMIT 10');
        System.debug('Total BenefitDisbursements in system: ' + accountBenefits.size());
        
        // Try to find specific BenefitDisbursements for this account
        List<SObject> accountSpecificBenefits = Database.query('SELECT Id, BenefitAssignmentId FROM BenefitDisbursement WHERE BenefitAssignment.ProgramEnrollment.ContactId = \'' + accountId + '\' LIMIT 10');
        System.debug('BenefitDisbursements for account ' + accountId + ': ' + accountSpecificBenefits.size());
    } catch (Exception e) {
        System.debug('Error querying BenefitDisbursements: ' + e.getMessage());
    }
    
    try {
        List<SObject> accountGoals = Database.query('SELECT COUNT(Id) totalGoals FROM GoalAssignmentDetail');
        System.debug('Total GoalAssignmentDetails in system: ' + accountGoals.size());
    } catch (Exception e) {
        System.debug('Error querying GoalAssignmentDetails: ' + e.getMessage());
    }
}

System.debug('=== DEBUG COMPLETE ===');