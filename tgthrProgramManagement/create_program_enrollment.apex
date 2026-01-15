// Create a ProgramEnrollment for Amanda so we can test the complete Benefits workflow
Id accountId = '001VY00000CGQ5rYAH';  // Amanda Arellano
Id programId = '11WVY000000GC6r2AG';  // 1440 Pine Program

// Get Amanda's PersonContactId
List<Account> accounts = [SELECT Id, PersonContactId FROM Account WHERE Id = :accountId];
if (accounts.isEmpty()) {
    System.debug('❌ Account not found: ' + accountId);
    return;
}

Id contactId = accounts[0].PersonContactId;
if (contactId == null) {
    System.debug('❌ Account is not a Person Account - no PersonContactId');
    return;
}

System.debug('Found PersonContactId: ' + contactId);

// Check if ProgramEnrollment already exists
List<SObject> existingEnrollments = Database.query(
    'SELECT Id, Status FROM ProgramEnrollment WHERE ContactId = :contactId AND ProgramId = :programId'
);

if (!existingEnrollments.isEmpty()) {
    SObject enrollment = existingEnrollments[0];
    String status = String.valueOf(enrollment.get('Status'));
    System.debug('Existing enrollment found with status: ' + status);
    
    // If it's not Active, update it to Active
    if (status != 'Active' && status != 'Enrolled') {
        enrollment.put('Status', 'Active');
        Database.update(enrollment);
        System.debug('✓ Updated enrollment status to Active: ' + enrollment.Id);
    } else {
        System.debug('✓ Enrollment already active: ' + enrollment.Id);
    }
} else {
    // Create new ProgramEnrollment
    SObject enrollment = Schema.getGlobalDescribe().get('ProgramEnrollment').newSObject();
    enrollment.put('ContactId', contactId);
    enrollment.put('ProgramId', programId);
    enrollment.put('Status', 'Enrolled');  // Try 'Enrolled' instead of 'Active'
    enrollment.put('StartDate', Date.today());
    
    Database.insert(enrollment);
    System.debug('✓ Created new ProgramEnrollment: ' + enrollment.Id);
}

System.debug('🎯 Amanda is now enrolled in 1440 Pine Program - ready for Benefits testing');