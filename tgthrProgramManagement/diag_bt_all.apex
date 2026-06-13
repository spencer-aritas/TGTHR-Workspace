Map<String, Schema.SObjectField> fields = Schema.getGlobalDescribe().get('BenefitType').getDescribe().fields.getMap();
List<String> fieldNames = new List<String>(fields.keySet());
fieldNames.sort();
for (String fname : fieldNames) {
    Schema.DescribeFieldResult f = fields.get(fname).getDescribe();
    System.debug(fname + ' | ' + f.getLabel() + ' | nillable=' + f.isNillable() + ' | type=' + f.getType());
}
