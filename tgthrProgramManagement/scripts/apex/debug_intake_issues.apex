// Test 1: ProgramEnrollment creation
System.debug('=== TEST 1: ProgramEnrollment Creation ===');
try {
    // Get a real program Id
    List<SObject> programs = Database.query('SELECT Id, Name FROM Program__c LIMIT 1');
    if (programs.isEmpty()) {
        System.debug('No Program__c records found - trying OutreachProgram');
        programs = Database.query('SELECT Id, Name FROM OutreachProgram LIMIT 1');
    }
    
    if (programs.isEmpty()) {
        System.debug('❌ No programs found at all');
    } else {
        Id programId = (Id) programs[0].get('Id');
        System.debug('Using program: ' + programs[0].get('Name') + ' (' + programId + ')');
        
        // Try the fixed approach
        Schema.SObjectType peType = Schema.getGlobalDescribe().get('ProgramEnrollment');
        System.debug('ProgramEnrollment SObjectType: ' + peType);
        
        if (peType != null) {
            SObject enrollment = peType.newSObject();
            System.debug('Created enrollment instance: ' + enrollment.getSObjectType());
            
            // Get a test account to test with
            List<Account> accounts = [SELECT Id FROM Account WHERE IsPersonAccount = true LIMIT 1];
            if (!accounts.isEmpty()) {
                enrollment.put('AccountId', accounts[0].Id);
                enrollment.put('ProgramId', programId);
                enrollment.put('Status', 'Pending');
                enrollment.put('StartDate', Date.today());
                
                Database.SaveResult sr = Database.insert(enrollment, false);
                if (sr.isSuccess()) {
                    System.debug('✅ ProgramEnrollment created! Id: ' + sr.getId());
                    // Clean up
                    delete enrollment;
                } else {
                    for (Database.Error e : sr.getErrors()) {
                        System.debug('❌ Insert Error: ' + e.getStatusCode() + ' - ' + e.getMessage());
                        System.debug('   Fields: ' + e.getFields());
                    }
                }
            } else {
                System.debug('No Person Account found to test with');
            }
        }
    }
} catch (Exception e) {
    System.debug('❌ Exception: ' + e.getMessage());
    System.debug(e.getStackTraceString());
}

// Test 2: Check valid Status picklist values
System.debug('=== TEST 2: ProgramEnrollment Status Values ===');
try {
    Schema.DescribeFieldResult dfr = Schema.getGlobalDescribe()
        .get('ProgramEnrollment')
        .getDescribe()
        .fields.getMap()
        .get('Status')
        .getDescribe();
    for (Schema.PicklistEntry e : dfr.getPicklistValues()) {
        if (e.isActive()) {
            System.debug('Active status: ' + e.getValue());
        }
    }
} catch (Exception e) {
    System.debug('❌ Could not get Status picklist: ' + e.getMessage());
}

// Test 3: Check recent Apex logs for callout errors
System.debug('=== TEST 3: Most recent intake case InteractionSummary ===');
try {
    List<Case> intakeCases = [SELECT Id, AccountId FROM Case WHERE Origin = 'Intake' ORDER BY CreatedDate DESC LIMIT 3];
    for (Case c : intakeCases) {
        List<SObject> sums = Database.query(
            'SELECT Id, Name FROM InteractionSummary__c WHERE Case__c = \'' + c.Id + '\' ORDER BY CreatedDate DESC LIMIT 1'
        );
        System.debug('Case ' + c.Id + ' -> InteractionSummaries: ' + sums.size());
        if (!sums.isEmpty()) {
            System.debug('  Latest: ' + sums[0].get('Id') + ' ' + sums[0].get('Name'));
        }
    }
} catch (Exception e) {
    System.debug('❌ Exception: ' + e.getMessage());
}
