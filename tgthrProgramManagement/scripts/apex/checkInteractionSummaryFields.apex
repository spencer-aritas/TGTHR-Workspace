// Check which fields exist on InteractionSummary
Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get('InteractionSummary').getDescribe().fields.getMap();

List<String> signFields = new List<String>();
for(String fieldName : fieldMap.keySet()) {
    if(fieldName.containsIgnoreCase('sign')) {
        signFields.add(fieldName);
    }
}

System.debug('Signature-related fields: ' + signFields);

// Also check for any signer/signed fields
List<String> signerFields = new List<String>();
for(String fieldName : fieldMap.keySet()) {
    if(fieldName.containsIgnoreCase('signer')) {
        signerFields.add(fieldName);
    }
}
System.debug('Signer-related fields: ' + signerFields);
