Map<String, Object> payload = InterviewDocumentService.buildInterviewDocumentPayload('8BVRT0000008VWT4A2');
List<Object> sections = (List<Object>)payload.get('sections');
System.debug('SECTION_COUNT=' + (sections == null ? 0 : sections.size()));
if (sections != null) {
    for (Object sectionObj : sections) {
        Map<String, Object> section = (Map<String, Object>)sectionObj;
        System.debug('SECTION=' + section.get('id') + '|' + section.get('kind'));
        if ((String)section.get('id') == 'CPT_CODES') {
            List<Object> items = (List<Object>)section.get('items');
            System.debug('CPT_COUNT=' + (items == null ? 0 : items.size()));
            if (items != null) {
                for (Object itemObj : items) {
                    Map<String, Object> item = (Map<String, Object>)itemObj;
                    System.debug('CPT_ITEM=' + item.get('code') + '|' + item.get('status') + '|' + item.get('units'));
                }
            }
        }
    }
}
