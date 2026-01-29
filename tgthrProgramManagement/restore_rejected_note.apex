// Restore the rejected note's action flags
InteractionSummary note = [SELECT Id FROM InteractionSummary WHERE Id = '8BVRT0000007lob4AA' LIMIT 1];
note.Action_Required__c = true;
note.Action_Assigned_To__c = '005VY000003VsDhYAK'; // Spencer Essey
note.Action_Escalated_By__c = '005VY000002qtSHYAY'; // Cami Boyer (who rejected it)
note.Action_Notes__c = 'Rejected: Please reword sentence about lawyer and court.';
update note;

System.debug('✅ Restored action flags on note: ' + note.Id);
