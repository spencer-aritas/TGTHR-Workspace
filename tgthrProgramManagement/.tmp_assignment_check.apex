List<String> participants = new List<String>{'001RT00000vLFhbYAG'};
BenefitDisbursementService.BenefitAssignmentCheckResult result = BenefitDisbursementService.checkBenefitAssignmentsWithParams(participants, '0jiRT0000000SfdYAE');
System.debug(JSON.serialize(result));
