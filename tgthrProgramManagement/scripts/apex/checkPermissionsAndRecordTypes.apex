// Script to check record types and permissions for BenefitAssignment
// This will help us understand any potential permission or RecordType issues

// 1. Check for record types on BenefitAssignment
Schema.DescribeSObjectResult baDescribe = Schema.getGlobalDescribe().get('BenefitAssignment').getDescribe();
Map<Id, Schema.RecordTypeInfo> rtMap = baDescribe.getRecordTypeInfosById();

System.debug('Record Types on BenefitAssignment:');
for (Id rtId : rtMap.keySet()) {
    Schema.RecordTypeInfo rt = rtMap.get(rtId);
    System.debug('  - ' + rt.getName() + ' (ID: ' + rt.getRecordTypeId() + ', Default: ' + rt.isDefaultRecordTypeMapping() + ', Available: ' + rt.isAvailable() + ')');
}

// 2. Check the permission profile
System.debug('Current user: ' + UserInfo.getName() + ' (' + UserInfo.getUserId() + ')');
System.debug('Profile: ' + UserInfo.getProfileId());

// 3. Check all required fields
Map<String, Schema.SObjectField> fieldMap = baDescribe.fields.getMap();
System.debug('Required fields on BenefitAssignment:');
for (String fieldName : fieldMap.keySet()) {
    Schema.DescribeFieldResult field = fieldMap.get(fieldName).getDescribe();
    Boolean isRequired = !field.isNillable() && !field.isDefaultedOnCreate();
    if (isRequired) {
        System.debug('  - ' + fieldName + ' (' + field.getLabel() + ')');
        System.debug('    * Type: ' + field.getType());
        System.debug('    * Createable: ' + field.isCreateable());
        
        if (field.getType() == Schema.DisplayType.REFERENCE) {
            System.debug('    * References: ' + field.getReferenceTo());
        }
    }
}

// 4. Check what benefits exist in the system
String benefitQuery = 'SELECT Id, Name, ProgramId, Program.Name FROM Benefit WHERE IsActive = true';
List<SObject> benefits = Database.query(benefitQuery);
System.debug('Active Benefits in the system:');
for (SObject b : benefits) {
    System.debug('  - ' + b.get('Name') + ' (ID: ' + b.get('Id') + ')');
    System.debug('    * Program: ' + b.getSObject('Program').get('Name') + ' (ID: ' + b.get('ProgramId') + ')');
}

// 5. Check what Program Enrollments exist for our test account
Id testAccountId = '001VY00000CGMfMYAX'; // Edwin Thompson
String enrollmentQuery = 'SELECT Id, AccountId, ProgramId, Program.Name, Status FROM ProgramEnrollment WHERE AccountId = :testAccountId';
List<SObject> enrollments = Database.query(enrollmentQuery);
System.debug('Program Enrollments for account ' + testAccountId + ':');
for (SObject pe : enrollments) {
    System.debug('  - ID: ' + pe.get('Id'));
    System.debug('    * Program: ' + pe.getSObject('Program').get('Name') + ' (ID: ' + pe.get('ProgramId') + ')');
    System.debug('    * Status: ' + pe.get('Status'));
}

// 6. Check if there are any validation rules on BenefitAssignment
System.debug('Unable to directly query validation rules via Apex. Please check Setup > Object Manager > BenefitAssignment > Validation Rules');

// 7. Try to create a record with System.runAs() if admin user is available
System.debug('Attempting to find a System Administrator user to run as...');
List<User> adminUsers = [SELECT Id, Name FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];

if (!adminUsers.isEmpty()) {
    User adminUser = adminUsers[0];
    System.debug('Found admin user: ' + adminUser.Name + ' (ID: ' + adminUser.Id + ')');
    
    System.runAs(adminUser) {
        System.debug('Running as admin user ' + UserInfo.getName());
        
        // Get the Program and Benefit IDs
        String programName = '1440 Pine';
        String benefitName = 'Housing';
        
        String programQuery = 'SELECT Id FROM Program WHERE Name = :programName LIMIT 1';
        List<SObject> programs = Database.query(programQuery);
        
        if (!programs.isEmpty()) {
            Id programId = (Id)programs[0].get('Id');
            
            String benefitQuery2 = 'SELECT Id FROM Benefit WHERE Name = :benefitName AND ProgramId = :programId LIMIT 1';
            List<SObject> benefitList = Database.query(benefitQuery2);
            
            if (!benefitList.isEmpty()) {
                Id benefitId = (Id)benefitList[0].get('Id');
                
                String peQuery = 'SELECT Id FROM ProgramEnrollment WHERE AccountId = :testAccountId AND ProgramId = :programId AND Status = \'Enrolled\' LIMIT 1';
                List<SObject> peList = Database.query(peQuery);
                
                if (!peList.isEmpty()) {
                    Id peId = (Id)peList[0].get('Id');
                    
                    // Create the BenefitAssignment
                    SObject ba = Schema.getGlobalDescribe().get('BenefitAssignment').newSObject();
                    ba.put('EnrolleeId', testAccountId);
                    ba.put('BenefitId', benefitId);
                    ba.put('ProgramEnrollmentId', peId);
                    ba.put('ParentRecordId', peId);
                    ba.put('Status', 'Active');
                    ba.put('StartDateTime', DateTime.now());
                    ba.put('past_participant_benefit__c', false);
                    
                    try {
                        Database.SaveResult result = Database.insert(ba, false);
                        
                        if (result.isSuccess()) {
                            System.debug('SUCCESS! Admin user created BenefitAssignment: ' + result.getId());
                        } else {
                            System.debug('Failed to create BenefitAssignment as admin. Errors:');
                            for (Database.Error err : result.getErrors()) {
                                System.debug('  * Error: ' + err.getStatusCode() + ' - ' + err.getMessage());
                                System.debug('    Fields: ' + err.getFields());
                            }
                        }
                    } catch (Exception e) {
                        System.debug('Exception as admin: ' + e.getMessage());
                        System.debug('Stack trace: ' + e.getStackTraceString());
                    }
                } else {
                    System.debug('No Program Enrollment found for account ' + testAccountId + ' and program ' + programId);
                }
            } else {
                System.debug('No Benefit found with name ' + benefitName + ' for program ' + programId);
            }
        } else {
            System.debug('No Program found with name ' + programName);
        }
    }
} else {
    System.debug('No System Administrator user found to run as');
}