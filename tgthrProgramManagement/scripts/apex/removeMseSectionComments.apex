// Remove section-specific MSE comment questions and keep a single MSE Comments question.
// - Deletes MSE_*_Comments__c questions for MSE subsections
// - Moves MSE_Comments__c to the end of its section

String templateNameLike = 'Comprehensive Intake';

List<InterviewTemplateVersion__c> versions = [
    SELECT Id, Name, Version__c, Status__c, InterviewTemplate__r.Name
    FROM InterviewTemplateVersion__c
    WHERE InterviewTemplate__r.Name LIKE :('%' + templateNameLike + '%')
    AND Status__c = 'Active'
    ORDER BY Version__c DESC, LastModifiedDate DESC
    LIMIT 1
];

if (versions.isEmpty()) {
    versions = [
        SELECT Id, Name, Version__c, Status__c, InterviewTemplate__r.Name
        FROM InterviewTemplateVersion__c
        WHERE InterviewTemplate__r.Name LIKE :('%' + templateNameLike + '%')
        ORDER BY LastModifiedDate DESC
        LIMIT 1
    ];
}

if (versions.isEmpty()) {
    System.debug('No InterviewTemplateVersion__c found for template name like: ' + templateNameLike);
    return;
}

InterviewTemplateVersion__c version = versions[0];
System.debug('Using template version: ' + version.Id + ' (' + version.Name + ')');

Set<String> sectionCommentApiNames = new Set<String>{
    'MSE_Observations_Comments__c',
    'MSE_Mood_Comments__c',
    'MSE_Cognition_Comments__c',
    'MSE_Perception_Comments__c',
    'MSE_Thoughts_Comments__c',
    'MSE_Behavior_Comments__c',
    'MSE_Insight_Comments__c',
    'MSE_Judgment_Comments__c'
};

List<InterviewQuestion__c> questions = [
    SELECT Id, API_Name__c, Section__c, Order__c
    FROM InterviewQuestion__c
    WHERE InterviewTemplateVersion__c = :version.Id
];

List<InterviewQuestion__c> toDelete = new List<InterviewQuestion__c>();
InterviewQuestion__c mseCommentsQuestion = null;

for (InterviewQuestion__c q : questions) {
    if (String.isBlank(q.API_Name__c)) {
        continue;
    }
    if (sectionCommentApiNames.contains(q.API_Name__c)) {
        toDelete.add(q);
        continue;
    }
    if (q.API_Name__c == 'MSE_Comments__c') {
        mseCommentsQuestion = q;
    }
}

if (!toDelete.isEmpty()) {
    delete toDelete;
    System.debug('Deleted ' + toDelete.size() + ' section-specific MSE comment questions.');
} else {
    System.debug('No section-specific MSE comment questions found to delete.');
}

if (mseCommentsQuestion != null && String.isNotBlank(mseCommentsQuestion.Section__c)) {
    Decimal maxOrder = null;
    for (InterviewQuestion__c q : questions) {
        if (q.Id == mseCommentsQuestion.Id) {
            continue;
        }
        if (sectionCommentApiNames.contains(q.API_Name__c)) {
            continue;
        }
        if (q.Section__c != null && q.Section__c == mseCommentsQuestion.Section__c) {
            if (maxOrder == null || (q.Order__c != null && q.Order__c > maxOrder)) {
                maxOrder = q.Order__c != null ? q.Order__c : maxOrder;
            }
        }
    }

    Decimal newOrder = maxOrder == null ? 1 : maxOrder + 1;
    mseCommentsQuestion.Order__c = newOrder;
    update mseCommentsQuestion;
    System.debug('Moved MSE_Comments__c to order ' + newOrder + ' in section ' + mseCommentsQuestion.Section__c + '.');
} else if (mseCommentsQuestion == null) {
    System.debug('MSE_Comments__c not found; no ordering updates applied.');
}

System.debug('MSE comments cleanup complete.');
