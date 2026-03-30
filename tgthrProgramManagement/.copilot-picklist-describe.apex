List<String> fieldNames = new List<String>{
    'Translator_Needed__pc',
    'Gender_Identity__pc',
    'PersonGenderIdentity',
    'PersonPronouns',
    'Race_and_Ethnicity__pc',
    'Sexual_Orientation__pc',
    'Veteran_Service__pc'
};
Map<String, Schema.SObjectField> fields = Account.SObjectType.getDescribe().fields.getMap();
for (String fieldName : fieldNames) {
    Schema.SObjectField token = fields.get(fieldName);
    if (token == null) {
        System.debug('FIELD_MISSING ' + fieldName);
        continue;
    }
    Schema.DescribeFieldResult d = token.getDescribe();
    System.debug('FIELD ' + fieldName + ' TYPE=' + String.valueOf(d.getType()));
    for (Schema.PicklistEntry entry : d.getPicklistValues()) {
        System.debug('PICK ' + fieldName + ' VALUE=' + entry.getValue() + ' LABEL=' + entry.getLabel() + ' ACTIVE=' + entry.isActive());
    }
}
