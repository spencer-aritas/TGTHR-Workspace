Map<String, Object> payload = InterviewDocumentService.buildInterviewDocumentPayload('8BVRT0000008VWT4A2');
List<Object> sections = (List<Object>)payload.get('sections');
System.debug('PAYLOAD sections=' + sections.size());
for (Object secObj : sections) {
    Map<String, Object> sec = (Map<String, Object>)secObj;
    System.debug('PAYLOAD section=' + sec.get('id') + '|' + sec.get('kind') + '|items=' + (((List<Object>)sec.get('items')) != null ? ((List<Object>)sec.get('items')).size() : 0));
    if ((String)sec.get('kind') == 'cpt_codes') {
        System.debug('PAYLOAD CPT=' + JSON.serialize(sec));
    }
}
