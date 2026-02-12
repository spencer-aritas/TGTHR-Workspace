Id interviewId = 'a0qRT00000EECKbYAP';
PendingDocumentationController.NoteApprovalDTO dto = PendingDocumentationController.getNoteForApproval(interviewId, 'Interview');
System.debug('CarePlan discharge date: ' + dto.carePlanDischargeDate);
System.debug('CarePlan discharge plan: ' + dto.carePlanDischargePlan);
System.debug('CarePlan next review: ' + dto.carePlanNextReviewDate);
System.debug('CarePlan consent participated: ' + dto.carePlanConsentParticipated);
System.debug('CarePlan consent offered: ' + dto.carePlanConsentOffered);
System.debug('Goals count: ' + (dto.goals != null ? dto.goals.size() : 0));
if (dto.goals != null) {
    for (Map<String, Object> g : dto.goals) {
        System.debug('Goal: ' + g);
    }
}
