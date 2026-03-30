Id noteId = '8BVRT0000008Z8f4AE';
PendingDocumentationController.NoteApprovalDTO dto = PendingDocumentationController.getNoteForApproval(noteId, 'Interaction');
System.debug('DTO benefits null? ' + (dto.benefits == null));
System.debug('DTO benefits size: ' + (dto.benefits == null ? -1 : dto.benefits.size()));
System.debug('DTO goals null? ' + (dto.goals == null));
System.debug('DTO goals size: ' + (dto.goals == null ? -1 : dto.goals.size()));
if (dto.benefits != null) {
    System.debug('DTO benefits payload: ' + JSON.serialize(dto.benefits));
}
if (dto.goals != null) {
    System.debug('DTO goals payload: ' + JSON.serialize(dto.goals));
}
