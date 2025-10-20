public with sharing class BenefitAssignmentService {
    
    @AuraEnabled
    public static List<String> createBenefitAssignments(String accountId, String programEnrollmentId, String createdByUserId) {
        List<String> results = new List<String>();
        
        try {
            // Get all active benefits for Street Outreach Program
            String benefitQuery = 'SELECT Id, Name, UnitOfMeasureId FROM Benefit WHERE ProgramId IN (SELECT ProgramId FROM ProgramEnrollment WHERE Id = :programEnrollmentId) AND IsActive = true';
            List<SObject> benefits = Database.query(benefitQuery);
            
            System.debug('Found ' + benefits.size() + ' benefits for program');
            
            List<SObject> benefitAssignments = new List<SObject>();
            
            for (SObject benefit : benefits) {
                SObject ba = Schema.getGlobalDescribe().get('BenefitAssignment').newSObject();
                ba.put('EnrolleeId', accountId);
                ba.put('BenefitId', benefit.get('Id'));
                ba.put('ProgramEnrollmentId', programEnrollmentId);
                ba.put('ParentRecordId', programEnrollmentId);
                ba.put('Status', 'Enrolled');
                ba.put('StartDateTime', Datetime.now());
                ba.put('UnitOfMeasureId', benefit.get('UnitOfMeasureId'));
                
                benefitAssignments.add(ba);
            }
            
            if (!benefitAssignments.isEmpty()) {
                Database.SaveResult[] saveResults = Database.insert(benefitAssignments, false);
                
                for (Integer i = 0; i < saveResults.size(); i++) {
                    Database.SaveResult sr = saveResults[i];
                    SObject benefit = benefits[i];
                    
                    if (sr.isSuccess()) {
                        results.add('Created BenefitAssignment for ' + benefit.get('Name') + ': ' + sr.getId());
                        System.debug('Successfully created BenefitAssignment: ' + sr.getId());
                    } else {
                        String errorMsg = 'Failed to create BenefitAssignment for ' + benefit.get('Name') + ': ';
                        for (Database.Error err : sr.getErrors()) {
                            errorMsg += err.getMessage() + ' ';
                        }
                        results.add(errorMsg);
                        System.debug(errorMsg);
                    }
                }
            }
            
        } catch (Exception e) {
            String errorMsg = 'Error creating BenefitAssignments: ' + e.getMessage();
            results.add(errorMsg);
            System.debug(errorMsg);
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
        
        return results;
    }
}