// Diagnostic: Insert a Benefit as admin to isolate whether the error is code or user-context
String programId = '11WVY000000GC3d2AG'; // Nest 56

// Resolve a BenefitType
List<SObject> btRows = Database.query('SELECT Id, Name FROM BenefitType ORDER BY CreatedDate ASC LIMIT 1');
if (btRows.isEmpty()) { System.debug('ERROR: No BenefitType records found'); return; }
Id benefitTypeId = (Id) btRows[0].get('Id');
System.debug('Using BenefitType: ' + btRows[0].get('Name') + ' / ' + benefitTypeId);
System.debug('Using ProgramId: ' + programId);

SObject b = Schema.getGlobalDescribe().get('Benefit').newSObject();
b.put('Name', 'DIAG TEST DELETE ME');
b.put('ProgramId', (Id) programId);
b.put('IsActive', true);
b.put('BenefitTypeId', benefitTypeId);
try {
    b.put('Lifecycle_State__c', 'Active');
} catch (Exception e) { System.debug('Lifecycle_State__c set failed: ' + e.getMessage()); }

System.debug('About to insert Benefit with fields:');
System.debug('  Name: ' + b.get('Name'));
System.debug('  ProgramId: ' + b.get('ProgramId'));
System.debug('  BenefitTypeId: ' + b.get('BenefitTypeId'));
System.debug('  IsActive: ' + b.get('IsActive'));

try {
    insert b;
    System.debug('SUCCESS: Benefit inserted, Id = ' + b.get('Id'));
    // Clean up
    delete b;
    System.debug('Cleaned up test record.');
} catch (Exception e) {
    System.debug('FAILED: ' + e.getMessage());
    System.debug('Stack: ' + e.getStackTraceString());
}
