Schema.DescribeSObjectResult d = Schema.getGlobalDescribe().get('Benefit').getDescribe();
for(String fn : d.fields.getMap().keySet()) {
    Schema.DescribeFieldResult f = d.fields.getMap().get(fn).getDescribe();
    if(!f.isNillable() && !f.isDefaultedOnCreate() && f.isCreateable()) {
        System.debug('REQUIRED_CREATABLE: ' + fn + ' type=' + f.getType());
    }
}
