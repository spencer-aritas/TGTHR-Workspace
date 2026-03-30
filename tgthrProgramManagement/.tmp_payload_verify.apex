Interview__c iv = [SELECT Id, Interaction_Summary__c FROM Interview__c WHERE Case__c='500RT00000U4TTZYA3' ORDER BY LastModifiedDate DESC LIMIT 1];
Map<String,Object> p = InterviewDocumentService.buildInterviewDocumentPayload(iv.Interaction_Summary__c);
System.debug('PAYLOAD_INTERVIEW=' + JSON.serialize(p.get('interview')));
List<Object> sections = (List<Object>)p.get('sections');
for (Object o : sections) {
  Map<String,Object> s = (Map<String,Object>)o;
  if ((String)s.get('kind') == 'signature_block') {
    System.debug('PAYLOAD_SIGNATURES=' + JSON.serialize(s.get('items')));
  }
}
