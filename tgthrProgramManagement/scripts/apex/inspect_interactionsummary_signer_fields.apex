Map<String, Schema.SObjectField> f = Schema.getGlobalDescribe().get('InteractionSummary').getDescribe().fields.getMap();
List<String> keys = new List<String>(f.keySet());
keys.sort();
System.debug('--- InteractionSummary signer-like fields ---');
for (String k : keys) {
    String lk = k.toLowerCase();
    if (lk.contains('sign') || lk.contains('manager') || lk.contains('approv')) {
        System.debug(k + ' :: ' + f.get(k).getDescribe().getType());
    }
}
