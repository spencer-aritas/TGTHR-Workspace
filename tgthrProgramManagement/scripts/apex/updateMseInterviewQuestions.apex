// Update Mental Status Exam (MSE) questions for the Comprehensive Intake template.
// - Collapses all MSE questions into the Mental Status Exam section
// - Updates labels and picklist values
// - Keeps a single MSE Comments question in the Mental Status Exam section

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

List<InterviewQuestion__c> questions = [
    SELECT Id, Label__c, API_Name__c, Response_Type__c, Picklist_Values__c, Section__c, Order__c, Required__c
    FROM InterviewQuestion__c
    WHERE InterviewTemplateVersion__c = :version.Id
];

Map<String, InterviewQuestion__c> questionsByApi = new Map<String, InterviewQuestion__c>();
Map<String, Decimal> sectionMaxOrder = new Map<String, Decimal>();
for (InterviewQuestion__c q : questions) {
    if (String.isNotBlank(q.API_Name__c)) {
        questionsByApi.put(q.API_Name__c, q);
    }
}

class MseConfig {
    String apiName;
    String label;
    String section;
    String responseType;
    List<String> picklistValues;
    Boolean isComment;

    MseConfig(String apiName, String label, String section, String responseType, List<String> picklistValues, Boolean isComment) {
        this.apiName = apiName;
        this.label = label;
        this.section = section;
        this.responseType = responseType;
        this.picklistValues = picklistValues;
        this.isComment = isComment;
    }
}

List<MseConfig> configs = new List<MseConfig>{
    new MseConfig('MSE_Appearance__c', 'Appearance', 'Mental Status Exam', 'Picklist',
        new List<String>{'Neat','Disheveled','Inappropriate','Bizarre','Other'}, false),
    new MseConfig('MSE_Speech__c', 'Speech', 'Mental Status Exam', 'Picklist',
        new List<String>{'Normal','Tangential','Pressured','Impoverished','Other'}, false),
    new MseConfig('MSE_Eye_Contact__c', 'Eye Contact', 'Mental Status Exam', 'Picklist',
        new List<String>{'Normal','Intense','Avoidant','Other'}, false),
    new MseConfig('MSE_Motor_Activity__c', 'Motor Activity', 'Mental Status Exam', 'Picklist',
        new List<String>{'Normal','Restless','Tics','Slowed','Other'}, false),
    new MseConfig('MSE_Affect__c', 'Affect', 'Mental Status Exam', 'Picklist',
        new List<String>{'Full','Constricted','Flat','Labile','Other'}, false),

    new MseConfig('MSE_Mood__c', 'Mood', 'Mental Status Exam', 'Picklist',
        new List<String>{'Euthymic','Angry','Anxious','Depressed','Euphoric','Irritable','Other'}, false),

    new MseConfig('MSE_Orientation_Impairment__c', 'Orientation Impairment', 'Mental Status Exam', 'Picklist',
        new List<String>{'None','Place','Object','Person','Time'}, false),
    new MseConfig('MSE_Memory_Impairment__c', 'Memory Impairment', 'Mental Status Exam', 'Picklist',
        new List<String>{'None','Short-Term','Long-Term','Other'}, false),
    new MseConfig('MSE_Attention__c', 'Attention', 'Mental Status Exam', 'Picklist',
        new List<String>{'Normal','Distracted','Other'}, false),

    new MseConfig('MSE_Hallucinations__c', 'Hallucinations', 'Mental Status Exam', 'Picklist',
        new List<String>{'None','Auditory','Visual','Other'}, false),
    new MseConfig('MSE_Perception_Other__c', 'Other', 'Mental Status Exam', 'Picklist',
        new List<String>{'None','Derealization','Depersonalization'}, false),

    new MseConfig('MSE_Suicidality__c', 'Suicidality', 'Mental Status Exam', 'Picklist',
        new List<String>{'None','Ideation','Plan','Intent','Self-Harm'}, false),
    new MseConfig('MSE_Homicidality__c', 'Homicidality', 'Mental Status Exam', 'Picklist',
        new List<String>{'None','Aggressive','Intent','Plan'}, false),
    new MseConfig('MSE_Delusions__c', 'Delusions', 'Mental Status Exam', 'Picklist',
        new List<String>{'None','Grandiose','Paranoid','Religious','Other'}, false),

    new MseConfig('MSE_Behavior__c', 'Behavior', 'Mental Status Exam', 'Picklist',
        new List<String>{'Cooperative','Guarded','Hyperactive','Agitated','Paranoid','Stereotyped','Aggressive','Bizarre','Withdrawn','Other'}, false),

    new MseConfig('MSE_Insight__c', 'Insight', 'Mental Status Exam', 'Picklist',
        new List<String>{'Good','Fair','Poor'}, false),

    new MseConfig('MSE_Judgment__c', 'Judgment', 'Mental Status Exam', 'Picklist',
        new List<String>{'Good','Fair','Poor'}, false),
    new MseConfig('MSE_Comments__c', 'MSE Comments', 'Mental Status Exam', 'LongText', null, true)
};

Set<String> commentApiNames = new Set<String>();
for (MseConfig config : configs) {
    if (config.isComment) {
        commentApiNames.add(config.apiName);
    }
}

for (InterviewQuestion__c q : questions) {
    if (String.isBlank(q.Section__c)) {
        continue;
    }
    if (String.isNotBlank(q.API_Name__c) && commentApiNames.contains(q.API_Name__c)) {
        continue;
    }
    Decimal currentMax = sectionMaxOrder.get(q.Section__c);
    if (currentMax == null || (q.Order__c != null && q.Order__c > currentMax)) {
        sectionMaxOrder.put(q.Section__c, q.Order__c != null ? q.Order__c : currentMax);
    }
}

List<InterviewQuestion__c> toUpdate = new List<InterviewQuestion__c>();
List<InterviewQuestion__c> toInsert = new List<InterviewQuestion__c>();

for (MseConfig config : configs) {
    InterviewQuestion__c existing = questionsByApi.get(config.apiName);
    if (existing != null) {
        existing.Label__c = config.label;
        existing.Section__c = config.section;
        existing.Response_Type__c = config.responseType;
        if (config.picklistValues != null) {
            existing.Picklist_Values__c = String.join(config.picklistValues, '\n');
        } else if (config.isComment) {
            existing.Picklist_Values__c = null;
        }
        if (config.isComment) {
            Decimal maxOrder = sectionMaxOrder.get(config.section);
            existing.Order__c = maxOrder == null ? 1 : maxOrder + 1;
            sectionMaxOrder.put(config.section, existing.Order__c);
        }
        toUpdate.add(existing);
        continue;
    }

    InterviewQuestion__c created = new InterviewQuestion__c();
    created.InterviewTemplateVersion__c = version.Id;
    created.API_Name__c = config.apiName;
    created.Label__c = config.label;
    created.Section__c = config.section;
    created.Response_Type__c = config.responseType;
    created.Required__c = false;
    if (config.picklistValues != null) {
        created.Picklist_Values__c = String.join(config.picklistValues, '\n');
    }

    Decimal nextOrder = sectionMaxOrder.get(config.section);
    if (nextOrder == null) {
        nextOrder = 1;
    } else {
        nextOrder = nextOrder + 1;
    }
    created.Order__c = nextOrder;
    sectionMaxOrder.put(config.section, nextOrder);

    toInsert.add(created);
}

if (!toUpdate.isEmpty()) {
    update toUpdate;
    System.debug('Updated ' + toUpdate.size() + ' MSE questions.');
} else {
    System.debug('No MSE questions needed updates.');
}

if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('Inserted ' + toInsert.size() + ' new MSE comments questions.');
} else {
    System.debug('No new MSE questions needed inserts.');
}

System.debug('MSE question updates complete.');
