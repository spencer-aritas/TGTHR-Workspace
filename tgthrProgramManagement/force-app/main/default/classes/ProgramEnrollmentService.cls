@RestResource(urlMapping='/ProgramEnrollmentService/*')
global with sharing class ProgramEnrollmentService {
    
    global class EnsureResult {
        @AuraEnabled public String encounterId;
        @AuraEnabled public Id programEnrollmentId;
        @AuraEnabled public Id programId;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String personUuid;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public Datetime startUtc;
        @AuraEnabled public Datetime endUtc;
        @AuraEnabled public String pos;
        @AuraEnabled public Boolean isCrisis;
        @AuraEnabled public String notes;
    }

    @HttpPost
    global static String ingestEncounter() {
        RestRequest req = RestContext.request;
        String requestBody = req.requestBody.toString();
        System.debug('REST request body: ' + requestBody);
        
        Map<String, Object> rawData = (Map<String, Object>) JSON.deserializeUntyped(requestBody);
        PwaEncounter e = parseEncounter(rawData);
        if (e == null) throw new AuraHandledException('Missing encounter');
        System.debug('Starting ingestEncounter for: ' + e.personUuid);

        // 1) Upsert Person Account by UUID__c with enhanced data
        SObject accountSObj = (SObject) Type.forName('Account').newInstance();
        accountSObj.put('UUID__c', e.personUuid);
        accountSObj.put('RecordTypeId', Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId());
        accountSObj.put('FirstName', e.firstName != null ? e.firstName : 'Unknown');
        accountSObj.put('LastName', e.lastName != null ? e.lastName : '(Unknown)');
        accountSObj.put('IsPersonAccount', true);
        
        // Add additional person account fields from payload
        if (rawData.containsKey('email') && rawData.get('email') != null) {
            accountSObj.put('PersonEmail', (String) rawData.get('email'));
        }
        if (rawData.containsKey('phone') && rawData.get('phone') != null) {
            accountSObj.put('PersonMobilePhone', (String) rawData.get('phone'));
        }
        if (rawData.containsKey('birthdate') && rawData.get('birthdate') != null) {
            String birthdateStr = (String) rawData.get('birthdate');
            try {
                accountSObj.put('PersonBirthdate', Date.valueOf(birthdateStr));
            } catch (Exception ex) {
                System.debug('Invalid birthdate format: ' + birthdateStr);
            }
        }
        
        Database.upsert(accountSObj, Schema.Account.UUID__c);
        Id accountId = accountSObj.Id;
        System.debug('Created/Updated Account: ' + accountId);

        // 2) Get Street Outreach Program - try by name first, then any active program
        System.debug('About to query for programs');
        Id programId;
        try {
            String programQuery = 'SELECT Id, Name FROM Program WHERE Name LIKE \'%Street%Outreach%\' OR Name LIKE \'%Outreach%\' LIMIT 1';
            List<SObject> programs = Database.query(programQuery);
            System.debug('First program query returned: ' + programs.size() + ' results');
            
            if (programs.isEmpty()) {
                // Fallback to any active program
                System.debug('No outreach programs found, trying active programs');
                programQuery = 'SELECT Id, Name FROM Program WHERE Status = \'Active\' LIMIT 1';
                programs = Database.query(programQuery);
                System.debug('Active program query returned: ' + programs.size() + ' results');
            }
            
            if (programs.isEmpty()) {
                // List all programs for debugging
                String allQuery = 'SELECT Id, Name, Status FROM Program LIMIT 10';
                List<SObject> allPrograms = Database.query(allQuery);
                System.debug('All programs in org: ' + allPrograms);
                throw new AuraHandledException('No active program found');
            }
            
            programId = (Id) programs[0].get('Id');
            System.debug('Found Program: ' + programId + ' Name: ' + programs[0].get('Name'));
        } catch (Exception ex) {
            System.debug('Exception in program query: ' + ex.getMessage());
            throw new AuraHandledException('Program query failed: ' + ex.getMessage());
        }

        // 3) Check for existing enrollment
        System.debug('About to check for existing enrollments');
        List<SObject> existingEnrollments;
        try {
            String enrollmentQuery = 'SELECT Id FROM ProgramEnrollment WHERE AccountId = :accountId AND ProgramId = :programId AND Status IN (\'Enrolled\',\'Active\') LIMIT 1';
            existingEnrollments = Database.query(enrollmentQuery);
            System.debug('Found ' + existingEnrollments.size() + ' existing enrollments');
        } catch (Exception ex) {
            System.debug('Exception in enrollment query: ' + ex.getMessage());
            throw new AuraHandledException('Enrollment query failed: ' + ex.getMessage());
        }
        
        Id enrollmentId;
        if (existingEnrollments.isEmpty()) {
            // Create new enrollment
            SObject enrollmentSObj = (SObject) Type.forName('ProgramEnrollment').newInstance();
            // enrollmentSObj.put('UUID__c', e.encounterUuid + '-PE'); // Remove if UUID__c doesn't exist
            enrollmentSObj.put('AccountId', accountId);
            enrollmentSObj.put('ProgramId', programId);
            enrollmentSObj.put('Status', 'Enrolled');
            enrollmentSObj.put('StartDate', Date.today());
            
            try {
                insert enrollmentSObj;
                enrollmentId = enrollmentSObj.Id;
                System.debug('Created new enrollment: ' + enrollmentId);
            } catch (Exception ex) {
                System.debug('Error creating enrollment: ' + ex.getMessage());
                throw new AuraHandledException('Failed to create program enrollment: ' + ex.getMessage());
            }
        } else {
            enrollmentId = existingEnrollments[0].Id;
            System.debug('Using existing enrollment: ' + enrollmentId);
        }

        // 4) Create Benefit Assignments for Program Benefits
        try {
            createBenefitAssignments(accountId, programId, enrollmentId);
            System.debug('Benefit assignments created successfully');
        } catch (Exception ex) {
            System.debug('Error creating benefit assignments: ' + ex.getMessage());
        }

        // 5) Create InteractionSummary
        try {
            String interactionId = InteractionSummaryService.createInteractionDirectly(
                accountId,
                programId,
                enrollmentId,
                e.notes,
                'Street Outreach Encounter',
                String.valueOf(Date.today()),
                false
            );
            System.debug('Created interaction: ' + interactionId);
        } catch (Exception ex) {
            System.debug('Error creating interaction: ' + ex.getMessage());
        }

        // 6) Create follow-up Task
        try {
            TaskService.createFollowUpTask(
                accountId,
                e.encounterUuid,
                e.notes,
                e.pos,
                e.isCrisis,
                e.startUtc,
                e.endUtc
            );
            System.debug('Created follow-up task');
        } catch (Exception ex) {
            System.debug('Error creating task: ' + ex.getMessage());
        }

        return JSON.serialize(new Map<String, Object>{
            'success' => true,
            'enrollmentId' => enrollmentId,
            'accountId' => accountId
        });
    }

    private static PwaEncounter parseEncounter(Map<String, Object> data) {
        PwaEncounter e = new PwaEncounter();
        e.encounterUuid = (String) data.get('encounterUuid');
        e.personUuid = (String) data.get('personUuid');
        e.firstName = (String) data.get('firstName');
        e.lastName = (String) data.get('lastName');
        e.pos = (String) data.get('pos');
        e.isCrisis = (Boolean) data.get('isCrisis');
        e.notes = (String) data.get('notes');
        
        // Parse datetime strings
        String startStr = (String) data.get('startUtc');
        String endStr = (String) data.get('endUtc');
        if (startStr != null) {
            e.startUtc = Datetime.valueOf(startStr.replace('T', ' ').replace('Z', ''));
        }
        if (endStr != null) {
            e.endUtc = Datetime.valueOf(endStr.replace('T', ' ').replace('Z', ''));
        }
        
        return e;
    }
    
    private static void createBenefitAssignments(Id accountId, Id programId, Id enrollmentId) {
        System.debug('Creating benefit assignments for account: ' + accountId + ', program: ' + programId);
        // Get all active benefits for the program
        String benefitQuery = 'SELECT Id FROM Benefit WHERE ProgramId = :programId AND IsActive = true';
        List<SObject> benefits = Database.query(benefitQuery);
        System.debug('Found ' + benefits.size() + ' benefits for program');
        
        if (benefits.isEmpty()) return;
        
        // Check existing assignments
        Set<Id> benefitIds = new Set<Id>();
        for (SObject benefit : benefits) {
            benefitIds.add((Id) benefit.get('Id'));
        }
        
        String existingQuery = 'SELECT BenefitId FROM BenefitAssignment WHERE EnrolleeId = :accountId AND BenefitId IN :benefitIds';
        List<SObject> existingAssignments = Database.query(existingQuery);
        
        Set<Id> existingBenefitIds = new Set<Id>();
        for (SObject assignment : existingAssignments) {
            existingBenefitIds.add((Id) assignment.get('BenefitId'));
        }
        
        // Create missing assignments
        List<SObject> assignmentsToCreate = new List<SObject>();
        for (SObject benefit : benefits) {
            Id benefitId = (Id) benefit.get('Id');
            if (!existingBenefitIds.contains(benefitId)) {
                SObject assignment = (SObject) Type.forName('BenefitAssignment').newInstance();
                assignment.put('EnrolleeId', accountId);
                assignment.put('BenefitId', benefitId);
                assignment.put('ProgramEnrollmentId', enrollmentId);
                assignment.put('ParentRecordId', enrollmentId);
                assignment.put('Status', 'Active');
                assignment.put('StartDateTime', Date.today());
                assignmentsToCreate.add(assignment);
            }
        }
        
        if (!assignmentsToCreate.isEmpty()) {
            insert assignmentsToCreate;
            System.debug('Created ' + assignmentsToCreate.size() + ' benefit assignments');
        } else {
            System.debug('No new benefit assignments needed');
        }
    }
}
