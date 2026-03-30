Interview__c iv = [
  SELECT Id, Interaction_Summary__c
  FROM Interview__c
  WHERE Case__c = '500RT00000U4TTZYA3'
  ORDER BY LastModifiedDate DESC
  LIMIT 1
];

Map<String, Object> p = InterviewDocumentService.buildInterviewDocumentPayload(iv.Interaction_Summary__c);
Map<String, Object> interview = (Map<String, Object>) p.get('interview');

Map<String, Object> dateSummary = new Map<String, Object>{
  'dateOfInteraction' => interview.get('dateOfInteraction'),
  'dateStarted' => interview.get('dateStarted'),
  'dateCompleted' => interview.get('dateCompleted'),
  'startTime' => interview.get('startTime'),
  'endTime' => interview.get('endTime')
};
System.debug('DOCGEN_DATES=' + JSON.serialize(dateSummary));

List<Object> sections = (List<Object>) p.get('sections');
for (Object o : sections) {
  Map<String, Object> s = (Map<String, Object>) o;
  if ((String) s.get('kind') == 'signature_block') {
    List<Object> items = (List<Object>) s.get('items');
    List<Map<String, Object>> sigDates = new List<Map<String, Object>>();
    for (Object i : items) {
      Map<String, Object> m = (Map<String, Object>) i;
      sigDates.add(new Map<String, Object>{
        'role' => m.get('role'),
        'dateSigned' => m.get('dateSigned')
      });
    }
    System.debug('DOCGEN_SIG_DATES=' + JSON.serialize(sigDates));
  }
}
