Map<String, Schema.SObjectField> noteFields = Schema.getGlobalDescribe().get('InteractionSummary').getDescribe().fields.getMap();

String fullySignedWhere = NoteSignatureLifecycleService.buildFullySignedWhereClause(noteFields, null);
String pendingWhere = NoteSignatureLifecycleService.buildPendingRequiredSignaturesWhereClause(noteFields, null);

System.debug('--- NOTE LIFECYCLE DYNAMIC SMOKE ---');
System.debug('fullySignedWhere=' + fullySignedWhere);
System.debug('pendingWhere=' + pendingWhere);

String base =
    ' FROM InteractionSummary ' +
    'WHERE InteractionPurpose IN (\'Clinical Note\', \'Case Note\', \'Peer Note\') ';

// 1) Completed notes that violate fully signed policy
Integer completedViolationCount = 0;
if (String.isNotBlank(fullySignedWhere)) {
    Integer completedTotal = Database.countQuery(
        'SELECT COUNT()' + base + 'AND Status = \'Completed\''
    );
    Integer completedValid = Database.countQuery(
        'SELECT COUNT()' + base +
        'AND Status = \'Completed\' ' +
        'AND (' + fullySignedWhere + ')'
    );
    completedViolationCount = completedTotal - completedValid;
    System.debug('completedTotal=' + completedTotal + ' completedValid=' + completedValid + ' completedViolationCount=' + completedViolationCount);
}

// 2) Pending (Published) manager-required notes that violate pending policy
Integer pendingViolationCount = 0;
if (String.isNotBlank(pendingWhere)) {
    Integer pendingTotal = Database.countQuery(
        'SELECT COUNT()' + base +
        'AND Status = \'Published\' ' +
        'AND Requires_Manager_Approval__c = true'
    );
    Integer pendingValid = Database.countQuery(
        'SELECT COUNT()' + base +
        'AND Status = \'Published\' ' +
        'AND Requires_Manager_Approval__c = true ' +
        'AND (' + pendingWhere + ')'
    );
    pendingViolationCount = pendingTotal - pendingValid;
    System.debug('pendingTotal=' + pendingTotal + ' pendingValid=' + pendingValid + ' pendingViolationCount=' + pendingViolationCount);
}

// 3) Recalled notes should have no signed artifacts left
List<String> signerChecks = new List<String>();
for (String f : new List<String>{
    'Staff_Signed_By__c',
    'Signed_By__c',
    'Signed_By_Name__c',
    'CaseManager_Signed_By__c',
    'PeerSupport_Signed_By__c',
    'Clinician_Signed_By__c'
}) {
    if (NoteSignatureLifecycleService.hasField(noteFields, f)) {
        signerChecks.add(f + ' != null');
    }
}
if (NoteSignatureLifecycleService.hasField(noteFields, 'Signed_Date__c')) {
    signerChecks.add('Signed_Date__c != null');
}
if (NoteSignatureLifecycleService.hasField(noteFields, 'Manager_Signed__c')) {
    signerChecks.add('Manager_Signed__c = true');
}

Integer recalledViolationCount = 0;
if (!signerChecks.isEmpty()) {
    String q3 = 'SELECT COUNT()' + base +
        'AND Status = \'Recalled\' ' +
        'AND (' + String.join(signerChecks, ' OR ') + ')';
    recalledViolationCount = Database.countQuery(q3);
    System.debug('recalledViolationCount=' + recalledViolationCount);
}

System.debug('SMOKE_RESULT completed=' + completedViolationCount + ' pending=' + pendingViolationCount + ' recalled=' + recalledViolationCount);
