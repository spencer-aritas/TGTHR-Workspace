Id noteId = '8BVRT0000008TrF4AU';
PendingDocumentationController.NoteApprovalDTO dto = PendingDocumentationController.getNoteForApproval(noteId, 'Interaction');
System.debug('goals size=' + (dto.goals == null ? -1 : dto.goals.size()));
System.debug('goals payload=' + JSON.serialize(dto.goals));
