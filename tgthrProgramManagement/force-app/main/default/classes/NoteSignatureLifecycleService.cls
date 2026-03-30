public with sharing class NoteSignatureLifecycleService {
    private static final List<String> AUTHOR_SIGNER_FIELD_API_NAMES = new List<String>{
        'Staff_Signed_By__c',
        'Signed_By__c',
        'Signed_By_Name__c',
        'CaseManager_Signed_By__c',
        'PeerSupport_Signed_By__c',
        'Clinician_Signed_By__c'
    };

    private static final List<String> AUTHOR_SIGNED_BOOLEAN_FIELD_API_NAMES = new List<String>{
        'Staff_Signed__c',
        'Clinician_Signed__c'
    };

    public static String buildAuthorSignedWhereClause(
        Map<String, Schema.SObjectField> noteFields,
        String fieldPrefix
    ) {
        List<String> parts = new List<String>();
        String prefix = normalizePrefix(fieldPrefix);

        for (String fieldApiName : AUTHOR_SIGNER_FIELD_API_NAMES) {
            if (hasField(noteFields, fieldApiName)) {
                parts.add(prefix + fieldApiName + ' != null');
            }
        }
        if (hasField(noteFields, 'Signed_Date__c')) {
            parts.add(prefix + 'Signed_Date__c != null');
        }

        for (String fieldApiName : AUTHOR_SIGNED_BOOLEAN_FIELD_API_NAMES) {
            if (hasField(noteFields, fieldApiName)) {
                parts.add(prefix + fieldApiName + ' = true');
            }
        }

        // Some orgs do not persist a dedicated author-signature field on InteractionSummary.
        // In that schema, author signature is implicit in the save/submission flow.
        // Use a tautology fallback so manager-based lifecycle predicates remain valid.
        if (parts.isEmpty()) {
            return prefix + 'Id != null';
        }

        return String.join(parts, ' OR ');
    }

    public static String buildFullySignedWhereClause(
        Map<String, Schema.SObjectField> noteFields,
        String fieldPrefix
    ) {
        String authorSignedClause = buildAuthorSignedWhereClause(noteFields, fieldPrefix);
        if (String.isBlank(authorSignedClause)) {
            return null;
        }

        String prefix = normalizePrefix(fieldPrefix);
        if (hasField(noteFields, 'Requires_Manager_Approval__c') && hasField(noteFields, 'Manager_Signed__c')) {
            return '(' + authorSignedClause + ') AND (' +
                prefix + 'Requires_Manager_Approval__c = false OR ' +
                prefix + 'Manager_Signed__c = true)';
        }

        return '(' + authorSignedClause + ')';
    }

    public static String buildPendingRequiredSignaturesWhereClause(
        Map<String, Schema.SObjectField> noteFields,
        String fieldPrefix
    ) {
        String authorSignedClause = buildAuthorSignedWhereClause(noteFields, fieldPrefix);
        if (String.isBlank(authorSignedClause)) {
            return null;
        }

        String prefix = normalizePrefix(fieldPrefix);
        if (hasField(noteFields, 'Requires_Manager_Approval__c') && hasField(noteFields, 'Manager_Signed__c')) {
            return '(' + authorSignedClause + ') AND ' +
                prefix + 'Requires_Manager_Approval__c = true AND ' +
                '(' + prefix + 'Manager_Signed__c = false OR ' + prefix + 'Manager_Signed__c = null)';
        }

        return null;
    }

    public static Boolean isAuthorSigned(SObject note, Map<String, Schema.SObjectField> noteFields) {
        Boolean hasExplicitAuthorEvidenceField = false;

        for (String fieldApiName : AUTHOR_SIGNER_FIELD_API_NAMES) {
            if (hasField(noteFields, fieldApiName)) {
                hasExplicitAuthorEvidenceField = true;
            }
            if (hasField(noteFields, fieldApiName) && note.get(fieldApiName) != null) {
                return true;
            }
        }

        if (hasField(noteFields, 'Signed_Date__c') && note.get('Signed_Date__c') != null) {
            return true;
        }

        if (hasField(noteFields, 'Signed_Date__c')) {
            hasExplicitAuthorEvidenceField = true;
        }

        for (String fieldApiName : AUTHOR_SIGNED_BOOLEAN_FIELD_API_NAMES) {
            if (hasField(noteFields, fieldApiName)) {
                hasExplicitAuthorEvidenceField = true;
            }
            if (hasField(noteFields, fieldApiName)) {
                Object isSigned = note.get(fieldApiName);
                if (isSigned != null && (Boolean) isSigned == true) {
                    return true;
                }
            }
        }

        // If no explicit author-signature fields exist on this schema,
        // treat author signature as satisfied by workflow design.
        if (!hasExplicitAuthorEvidenceField) {
            return true;
        }

        return false;
    }

    public static Boolean isFullySigned(SObject note, Map<String, Schema.SObjectField> noteFields) {
        Boolean authorSigned = isAuthorSigned(note, noteFields);
        if (!authorSigned) {
            return false;
        }

        if (hasField(noteFields, 'Requires_Manager_Approval__c') && hasField(noteFields, 'Manager_Signed__c')) {
            Object reqApproval = note.get('Requires_Manager_Approval__c');
            Boolean requiresManager = reqApproval != null && (Boolean) reqApproval == true;
            if (requiresManager) {
                Object managerSigned = note.get('Manager_Signed__c');
                return managerSigned != null && (Boolean) managerSigned == true;
            }
        }

        return true;
    }

    public static Boolean isPendingRequiredSignatures(SObject note, Map<String, Schema.SObjectField> noteFields) {
        Boolean authorSigned = isAuthorSigned(note, noteFields);
        if (!authorSigned) {
            return false;
        }

        if (hasField(noteFields, 'Requires_Manager_Approval__c') && hasField(noteFields, 'Manager_Signed__c')) {
            Object reqApproval = note.get('Requires_Manager_Approval__c');
            Boolean requiresManager = reqApproval != null && (Boolean) reqApproval == true;
            if (!requiresManager) {
                return false;
            }
            Object managerSigned = note.get('Manager_Signed__c');
            return managerSigned == null || (Boolean) managerSigned == false;
        }

        return false;
    }

    public static Boolean hasField(Map<String, Schema.SObjectField> fieldMap, String fieldApiName) {
        if (fieldMap == null || String.isBlank(fieldApiName)) {
            return false;
        }
        for (String key : fieldMap.keySet()) {
            if (key != null && key.equalsIgnoreCase(fieldApiName)) {
                return true;
            }
        }
        return false;
    }

    private static String normalizePrefix(String fieldPrefix) {
        if (String.isBlank(fieldPrefix)) {
            return '';
        }
        if (fieldPrefix.endsWith('.')) {
            return fieldPrefix;
        }
        return fieldPrefix + '.';
    }
}
