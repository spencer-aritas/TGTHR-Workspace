SObject note = Database.query('SELECT Id, AccountId, RelatedRecordId FROM InteractionSummary WHERE Id = \'8BVRT0000008Z8f4AE\' LIMIT 1');
Id accountId = (Id) note.get('AccountId');
Id caseId = (Id) note.get('RelatedRecordId');
System.debug('note accountId=' + accountId + ' caseId=' + caseId);
System.debug('case benefits=' + JSON.serialize(ClinicalNoteController.getCaseManagementBenefits(caseId)));
List<SObject> pes = Database.query('SELECT Id, Status, AccountId, ProgramId, Program__c, CreatedDate FROM ProgramEnrollment WHERE AccountId = :accountId ORDER BY CreatedDate DESC');
System.debug('program enrollments=' + JSON.serialize(pes));
