Id caseId = '500VY00000BI429YAD';
System.debug('Clinical count=' + ClinicalNoteController.getClinicalBenefits(caseId).size());
System.debug('Peer count=' + ClinicalNoteController.getPeerBenefits(caseId).size());
System.debug('CaseMgmt count=' + ClinicalNoteController.getCaseManagementBenefits(caseId).size());
