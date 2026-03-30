Id caseId = '500RT00000bt0QHYAY';
Case c = [SELECT AccountId FROM Case WHERE Id = :caseId LIMIT 1];
List<Map<String, String>> result = ClinicalNoteController.getExistingDiagnoses(caseId, c.AccountId);
System.debug('DIAG_RESULT=' + JSON.serializePretty(result));
System.debug('DIAG_COUNT=' + result.size());
