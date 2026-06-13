Map<String, Schema.SObjectField> fields = Schema.getGlobalDescribe().get('BenefitType').getDescribe().fields.getMap();
for (String fname : fields.keySet()) {
    Schema.DescribeFieldResult f = fields.get(fname).getDescribe();
    if (!f.isNillable() && !f.isDefaultedOnCreate()) {
        System.debug('Required: ' + fname + ' label: ' + f.getLabel());
    }
}
