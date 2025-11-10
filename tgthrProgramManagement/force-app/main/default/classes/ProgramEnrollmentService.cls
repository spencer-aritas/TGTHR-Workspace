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

        // 3) Ensure participant has an active Case record
        Id ownerId;
        try {
            String createdByUserId = (String) rawData.get('createdByUserId');
            if (String.isNotBlank(createdByUserId)) {
                ownerId = Id.valueOf(createdByUserId);
            }
        } catch (Exception ex) {
            System.debug('Invalid createdByUserId provided: ' + ex.getMessage());
        }
        Id caseId = ensureActiveCase(accountId, ownerId);

        // 4) Check for existing enrollment
        System.debug('About to check for existing enrollments');
        List<SObject> existingEnrollments;
        try {
            String enrollmentQuery = 'SELECT Id, Case__c FROM ProgramEnrollment WHERE AccountId = :accountId AND ProgramId = :programId AND Status IN (\'Enrolled\',\'Active\') LIMIT 1';
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
            if (caseId != null) {
                enrollmentSObj.put('Case__c', caseId);
            }
            
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
            if (caseId != null) {
                Object existingCase = existingEnrollments[0].get('Case__c');
                if (existingCase == null) {
                    SObject enrollmentUpdate = (SObject) Type.forName('ProgramEnrollment').newInstance();
                    enrollmentUpdate.put('Id', enrollmentId);
                    enrollmentUpdate.put('Case__c', caseId);
                    try {
                        update enrollmentUpdate;
                        System.debug('Updated enrollment with Case__c: ' + enrollmentId);
                    } catch (Exception updateEx) {
                        System.debug('Failed to update enrollment Case__c: ' + updateEx.getMessage());
                    }
                }
            }
        }

        // 5) Create Benefit Assignments and Disbursements using BenefitDisbursementService
        System.debug('About to create benefit assignments and disbursements using service');
        try {
            List<Id> disbursementIds = createBenefitDisbursementsUsingService(accountId, programId, enrollmentId, e);
            System.debug('Created ' + disbursementIds.size() + ' benefit disbursements via service');
            
            // 6) Create Tasks on BenefitDisbursements for validation
            String createdByUserId = (String) rawData.get('createdByUserId');
            System.debug('About to create validation tasks for ' + disbursementIds.size() + ' disbursements');
            for (Id disbursementId : disbursementIds) {
                try {
                    TaskService.TaskCreationDTO taskDto = new TaskService.TaskCreationDTO(
                        disbursementId,
                        e.encounterUuid,
                        e.notes,
                        e.pos,
                        e.isCrisis,
                        e.startUtc,
                        e.endUtc,
                        createdByUserId
                    );
                    Id taskId = TaskService.createValidationTask(taskDto);
                    System.debug('Created validation task: ' + taskId + ' for disbursement: ' + disbursementId);
                } catch (Exception ex) {
                    System.debug('Error creating validation task for disbursement ' + disbursementId + ': ' + ex.getMessage());
                    System.debug('Task creation stack trace: ' + ex.getStackTraceString());
                }
            }
        } catch (Exception ex) {
                System.debug('Error creating benefit assignments and disbursements: ' + ex.getMessage());
            System.debug('Benefit creation stack trace: ' + ex.getStackTraceString());
        }

        // 7) Create InteractionSummary
        try {
            String createdByUserId = (String) rawData.get('createdByUserId');
            String interactionId = InteractionSummaryService.createInteractionDirectly(
                accountId,
                programId,
                null,
                e.notes,
                'Street Outreach Encounter',
                String.valueOf(Date.today()),
                false,
                caseId != null ? String.valueOf(caseId) : null
            );
            System.debug('Created interaction: ' + interactionId);
        } catch (Exception ex) {
            System.debug('Error creating interaction: ' + ex.getMessage());
        }

        return JSON.serialize(new Map<String, Object>{
            'success' => true,
            'enrollmentId' => enrollmentId,
            'accountId' => accountId,
            'caseId' => caseId
        });
    }

    private static Id ensureActiveCase(Id accountId, Id ownerId) {
        if (accountId == null) {
            return null;
        }
        try {
            List<Case> existingCases = [
                SELECT Id, Status
                FROM Case
                WHERE AccountId = :accountId AND IsClosed = false
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!existingCases.isEmpty()) {
                return existingCases[0].Id;
            }
        } catch (Exception ex) {
            System.debug('Error querying existing Case: ' + ex.getMessage());
        }

        Case newCase = new Case();
        newCase.AccountId = accountId;
        if (ownerId != null) {
            newCase.OwnerId = ownerId;
        }
        // Determine an open status to use
        String openStatus = 'New';
        try {
            List<CaseStatus> statusOptions = [
                SELECT MasterLabel
                FROM CaseStatus
                WHERE IsDefault = true AND IsClosed = false
                LIMIT 1
            ];
            if (!statusOptions.isEmpty()) {
                openStatus = statusOptions[0].MasterLabel;
            }
        } catch (Exception statusEx) {
            System.debug('Unable to determine default Case status: ' + statusEx.getMessage());
        }
        newCase.Status = openStatus;
        newCase.Origin = 'PWA Intake';
        newCase.Subject = 'Street Outreach Case - ' + Date.today().format();

        try {
            insert newCase;
            System.debug('Created new Case for account ' + accountId + ': ' + newCase.Id);
            return newCase.Id;
        } catch (Exception insertEx) {
            System.debug('Failed to create Case: ' + insertEx.getMessage());
            return null;
        }
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
    
    private static List<Id> createBenefitDisbursementsUsingService(Id accountId, Id programId, Id enrollmentId, PwaEncounter e) {
        System.debug('Creating benefit disbursements using BenefitDisbursementService for account: ' + accountId + ', program: ' + programId);
        List<Id> disbursementIds = new List<Id>();
        
        try {
            // Get all active benefits for the program
            String benefitQuery = 'SELECT Id FROM Benefit WHERE ProgramId = :programId AND IsActive = true';
            List<SObject> benefits = Database.query(benefitQuery);
            System.debug('Found ' + benefits.size() + ' benefits for program');
            
            if (benefits.isEmpty()) return disbursementIds;
            
            // Create disbursements for each benefit using the proven service pattern
            for (SObject benefit : benefits) {
                Id benefitId = (Id) benefit.get('Id');
                System.debug('Processing benefit: ' + benefitId);
                
                try {
                    // Create a custom disbursement since BenefitDisbursementService doesn't set the right datetime fields
                    List<BenefitDisbursementService.DisburseResult> results = createCustomDisbursement(
                        accountId,
                        benefitId,
                        programId,
                        enrollmentId
                    );
                    
                    // Collect successful disbursement IDs
                    for (BenefitDisbursementService.DisburseResult result : results) {
                        if (result.success && result.disbursementId != null) {
                            disbursementIds.add(result.disbursementId);
                            System.debug('Created disbursement: ' + result.disbursementId + ' for benefit: ' + benefitId);
                        } else {
                            System.debug('Failed to create disbursement for benefit ' + benefitId + ': ' + result.message);
                        }
                    }
                } catch (Exception ex) {
                    System.debug('Error creating disbursement for benefit ' + benefitId + ': ' + ex.getMessage());
                }
            }
            
            System.debug('Successfully created ' + disbursementIds.size() + ' disbursements using service');
            
        } catch (Exception ex) {
            System.debug('Error in createBenefitDisbursementsUsingService: ' + ex.getMessage());
            System.debug('Stack trace: ' + ex.getStackTraceString());
        }
        
        return disbursementIds;
    }
    
    private static List<BenefitDisbursementService.DisburseResult> createCustomDisbursement(Id accountId, Id benefitId, Id programId, Id enrollmentId) {
        List<BenefitDisbursementService.DisburseResult> results = new List<BenefitDisbursementService.DisburseResult>();
        
        try {
            // First ensure benefit assignment exists using the service
            Map<String, Boolean> assignmentResults = BenefitDisbursementService.createMissingBenefitAssignments(
                new List<String>{ String.valueOf(accountId) },
                String.valueOf(benefitId),
                String.valueOf(programId),
                null
            );
            
            // Get the benefit assignment
            String assignmentQuery = 'SELECT Id FROM BenefitAssignment WHERE EnrolleeId = :accountId AND BenefitId = :benefitId LIMIT 1';
            List<SObject> assignments = Database.query(assignmentQuery);
            
            if (assignments.isEmpty()) {
                BenefitDisbursementService.DisburseResult result = new BenefitDisbursementService.DisburseResult();
                result.accountId = accountId;
                result.success = false;
                result.message = 'No benefit assignment found';
                results.add(result);
                return results;
            }
            
            Id assignmentId = (Id) assignments[0].get('Id');
            
            // Create disbursement with correct datetime fields
            Datetime now = Datetime.now();
            Datetime endTime = now.addMinutes(15);
            
            SObject disbursement = Schema.getGlobalDescribe().get('BenefitDisbursement').newSObject();
            disbursement.put('BenefitAssignmentId', assignmentId);
            disbursement.put('ProgramEnrollmentId', enrollmentId);
            disbursement.put('StartDate', now); // StartDate = NOW (datetime field)
            disbursement.put('EndDate', endTime); // EndDate = NOW + 15 minutes (datetime field)
            disbursement.put('ActualCompletionDate', now); // ActualCompletionDate = NOW
            disbursement.put('DisbursedQuantity', 1);
            disbursement.put('Description', 'Street Outreach Intake');
            
            insert disbursement;
            
            BenefitDisbursementService.DisburseResult result = new BenefitDisbursementService.DisburseResult();
            result.accountId = accountId;
            result.success = true;
            result.disbursementId = (Id) disbursement.get('Id');
            result.message = 'Created';
            results.add(result);
            
        } catch (Exception ex) {
            BenefitDisbursementService.DisburseResult result = new BenefitDisbursementService.DisburseResult();
            result.accountId = accountId;
            result.success = false;
            result.message = 'Error: ' + ex.getMessage();
            results.add(result);
        }
        
        return results;
    }
}
