String templateName = 'Casey Life Skills - Short Form';
String versionName = templateName + ' v1';
String sectionName = 'Casey Life Skills';
String picklistValues = String.join(
    new List<String>{ 'Yes', 'Mostly Yes', 'Somewhat', 'Mostly No', 'No' },
    '\n'
);

List<Map<String, String>> questionDefinitions = new List<Map<String, String>>{
    new Map<String, String>{
        'label' => 'I know how to access information on the internet safely.',
        'apiName' => 'CLS_Internet_Safety__c',
        'mapsTo' => 'Assessment__c.CLS_Internet_Safety__c',
        'helpText' => 'Digital safety and evaluating online information.'
    },
    new Map<String, String>{
        'label' => 'I understand why it is important to read and understand the food labels to see calories, serving size, fat, sugar, and salt for healthy eating.',
        'apiName' => 'CLS_Food_Labels__c',
        'mapsTo' => 'Assessment__c.CLS_Food_Labels__c',
        'helpText' => 'Reading labels to make healthier food choices.'
    },
    new Map<String, String>{
        'label' => 'I know how to use a washer, dryer, and detergent to clean my clothes.',
        'apiName' => 'CLS_Laundry__c',
        'mapsTo' => 'Assessment__c.CLS_Laundry__c',
        'helpText' => 'Laundry basics and routine self-care tasks.'
    },
    new Map<String, String>{
        'label' => 'I know how to positively manage my mental health when I am having a difficult day.',
        'apiName' => 'CLS_Mental_Health_Coping__c',
        'mapsTo' => 'Assessment__c.CLS_Mental_Health_Coping__c',
        'helpText' => 'Coping skills and emotional regulation.'
    },
    new Map<String, String>{
        'label' => 'I know where to get reliable information about safe sex and pregnancy.',
        'apiName' => 'CLS_Safe_Sex_Info__c',
        'mapsTo' => 'Assessment__c.CLS_Safe_Sex_Info__c',
        'helpText' => 'Reliable reproductive health information.'
    },
    new Map<String, String>{
        'label' => 'I know how to be respectful of people with different beliefs, opinions, and cultures.',
        'apiName' => 'CLS_Respect_Differences__c',
        'mapsTo' => 'Assessment__c.CLS_Respect_Differences__c',
        'helpText' => 'Respect and cultural responsiveness.'
    },
    new Map<String, String>{
        'label' => 'I know how to identify if my relationships show signs of any emotional, physical, and mental abuse.',
        'apiName' => 'CLS_Abuse_Relationship_Signs__c',
        'mapsTo' => 'Assessment__c.CLS_Abuse_Relationship_Signs__c',
        'helpText' => 'Recognizing unsafe or abusive relationship patterns.'
    },
    new Map<String, String>{
        'label' => 'I understand how to use online banking to keep track of my money.',
        'apiName' => 'CLS_Online_Banking__c',
        'mapsTo' => 'Assessment__c.CLS_Online_Banking__c',
        'helpText' => 'Tracking money and financial activity online.'
    },
    new Map<String, String>{
        'label' => 'I plan for bills and other expenses that I must pay for regularly (e.g., car and/or health insurance, cell phone, eating out, rent, video games).',
        'apiName' => 'CLS_Budgeting_Planning__c',
        'mapsTo' => 'Assessment__c.CLS_Budgeting_Planning__c',
        'helpText' => 'Budgeting and planning for recurring expenses.'
    },
    new Map<String, String>{
        'label' => 'I know how to safely use public transportation (or rideshare services such as Uber/Lyft) to get to where I need to go.',
        'apiName' => 'CLS_Transportation_Safety__c',
        'mapsTo' => 'Assessment__c.CLS_Transportation_Safety__c',
        'helpText' => 'Safe travel and transportation planning.'
    },
    new Map<String, String>{
        'label' => 'I know who to ask to get documents I need for work (e.g., social security card, birth certificate, state ID, or work permit).',
        'apiName' => 'CLS_Work_Documents__c',
        'mapsTo' => 'Assessment__c.CLS_Work_Documents__c',
        'helpText' => 'Getting required documents for employment.'
    },
    new Map<String, String>{
        'label' => 'I know how to use a planner, calendar, or phone to plan and keep track of important dates and assignments.',
        'apiName' => 'CLS_Planner_Calendar__c',
        'mapsTo' => 'Assessment__c.CLS_Planner_Calendar__c',
        'helpText' => 'Planning, reminders, and time management.'
    },
    new Map<String, String>{
        'label' => 'I know how to use reliable online platforms to find information about job training opportunities.',
        'apiName' => 'CLS_Job_Training_Research__c',
        'mapsTo' => 'Assessment__c.CLS_Job_Training_Research__c',
        'helpText' => 'Finding training and workforce development information.'
    },
    new Map<String, String>{
        'label' => 'I know where to find advice about how to choose an education program.',
        'apiName' => 'CLS_Education_Program_Advice__c',
        'mapsTo' => 'Assessment__c.CLS_Education_Program_Advice__c',
        'helpText' => 'Choosing an education or certification program.'
    },
    new Map<String, String>{
        'label' => 'I know how to share my views on news and politics responsibly.',
        'apiName' => 'CLS_Responsible_Civic_Voice__c',
        'mapsTo' => 'Assessment__c.CLS_Responsible_Civic_Voice__c',
        'helpText' => 'Responsible civic participation and discussion.'
    },
    new Map<String, String>{
        'label' => 'I know how to research information to improve my own understanding of a topic.',
        'apiName' => 'CLS_Research_Skills__c',
        'mapsTo' => 'Assessment__c.CLS_Research_Skills__c',
        'helpText' => 'Research skills and source evaluation.'
    },
    new Map<String, String>{
        'label' => 'I know my permanency goal (e.g., adoption, guardianship, independence, and return to home).',
        'apiName' => 'CLS_Permanency_Goal__c',
        'mapsTo' => 'Assessment__c.CLS_Permanency_Goal__c',
        'helpText' => 'Understanding permanency planning goals.'
    },
    new Map<String, String>{
        'label' => 'I understand if I am eligible for extended foster care in my state after I am 18 years old.',
        'apiName' => 'CLS_Extended_Foster_Care__c',
        'mapsTo' => 'Assessment__c.CLS_Extended_Foster_Care__c',
        'helpText' => 'Understanding extended foster care eligibility.'
    },
    new Map<String, String>{
        'label' => 'I believe I have a support system that will help me succeed.',
        'apiName' => 'CLS_Support_System_Belief__c',
        'mapsTo' => 'Assessment__c.CLS_Support_System_Belief__c',
        'helpText' => 'Confidence in social and practical supports.'
    },
    new Map<String, String>{
        'label' => 'Most days, I feel proud of the way I am leading my life.',
        'apiName' => 'CLS_Proud_Life_Direction__c',
        'mapsTo' => 'Assessment__c.CLS_Proud_Life_Direction__c',
        'helpText' => 'Sense of pride and direction in daily life.'
    }
};

List<InterviewTemplate__c> existingTemplates = [
    SELECT Id, Name, UUID__c, Active__c, Category__c, Status__c, Available_for_Mobile__c,
           Mobile_Active_Since__c, Change_Summary__c
    FROM InterviewTemplate__c
    WHERE Name = :templateName
    LIMIT 1
];

InterviewTemplate__c templateRecord;
if (existingTemplates.isEmpty()) {
    templateRecord = new InterviewTemplate__c(
        Name = templateName,
        UUID__c = EncodingUtil.convertToHex(
            Crypto.generateDigest(
                'SHA1',
                Blob.valueOf(String.valueOf(System.now().getTime()) + String.valueOf(Crypto.getRandomLong()))
            )
        ).left(32)
    );
} else {
    templateRecord = existingTemplates[0];
    if (String.isBlank(templateRecord.UUID__c)) {
        templateRecord.UUID__c = EncodingUtil.convertToHex(
            Crypto.generateDigest(
                'SHA1',
                Blob.valueOf(String.valueOf(System.now().getTime()) + String.valueOf(Crypto.getRandomLong()))
            )
        ).left(32);
    }
}

templateRecord.Active__c = true;
templateRecord.Category__c = 'Intake';
templateRecord.Status__c = 'Active';
templateRecord.Available_for_Mobile__c = true;
templateRecord.Mobile_Active_Since__c = Date.today();
templateRecord.Change_Summary__c = 'Casey Life Skills short form seeded for mobile-only launch.';
upsert templateRecord;

List<InterviewTemplateVersion__c> existingVersions = [
    SELECT Id, Name, UUID__c, Version__c, Status__c, Variant__c, Effective_From__c, Effective_To__c
    FROM InterviewTemplateVersion__c
    WHERE InterviewTemplate__c = :templateRecord.Id
    ORDER BY Version__c DESC NULLS LAST, CreatedDate DESC
    LIMIT 1
];

InterviewTemplateVersion__c versionRecord;
if (existingVersions.isEmpty()) {
    versionRecord = new InterviewTemplateVersion__c(
        InterviewTemplate__c = templateRecord.Id,
        UUID__c = EncodingUtil.convertToHex(
            Crypto.generateDigest(
                'SHA1',
                Blob.valueOf(String.valueOf(System.now().getTime()) + String.valueOf(Crypto.getRandomLong()))
            )
        ).left(32)
    );
} else {
    versionRecord = existingVersions[0];
    if (String.isBlank(versionRecord.UUID__c)) {
        versionRecord.UUID__c = EncodingUtil.convertToHex(
            Crypto.generateDigest(
                'SHA1',
                Blob.valueOf(String.valueOf(System.now().getTime()) + String.valueOf(Crypto.getRandomLong()))
            )
        ).left(32);
    }
}

versionRecord.Name = versionName;
versionRecord.Version__c = 1;
versionRecord.Status__c = 'Active';
versionRecord.Variant__c = 'Standard';
versionRecord.Effective_From__c = Date.today();
versionRecord.Effective_To__c = null;
upsert versionRecord;

List<InterviewQuestion__c> existingQuestions = [
    SELECT Id FROM InterviewQuestion__c WHERE InterviewTemplateVersion__c = :versionRecord.Id
];
if (!existingQuestions.isEmpty()) {
    delete existingQuestions;
}

List<InterviewQuestion__c> questionsToInsert = new List<InterviewQuestion__c>();
Integer orderCounter = 1;
for (Map<String, String> definition : questionDefinitions) {
    questionsToInsert.add(new InterviewQuestion__c(
        Name = definition.get('apiName').replace('__c', '').replace('_', ' '),
        InterviewTemplateVersion__c = versionRecord.Id,
        Label__c = definition.get('label'),
        API_Name__c = definition.get('apiName'),
        Section__c = sectionName,
        Help_Text__c = definition.get('helpText'),
        Maps_To__c = definition.get('mapsTo'),
        Order__c = orderCounter,
        Response_Type__c = 'Picklist',
        Required__c = false,
        Sensitive__c = false,
        Picklist_Values__c = picklistValues,
        UUID__c = EncodingUtil.convertToHex(
            Crypto.generateDigest(
                'SHA1',
                Blob.valueOf(String.valueOf(System.now().getTime()) + String.valueOf(Crypto.getRandomLong()))
            )
        ).left(32),
        Status__c = 'Active',
        Approver__c = UserInfo.getUserId()
    ));
    orderCounter++;
}
insert questionsToInsert;

ManifestGeneratorService.GenerateResult manifestResult = ManifestGeneratorService.generateManifest(templateRecord.Id);
if (manifestResult != null && manifestResult.success == true) {
    InterviewTemplateController.updatePublishedTemplate(
        templateRecord.Id,
        'Active',
        true,
        'Seeded Casey Life Skills short form.',
        manifestResult.manifestJson,
        manifestResult.contentHash,
        'Active'
    );
}

System.debug('Created or updated template: ' + templateRecord.Id);
System.debug('Created or updated version: ' + versionRecord.Id);
System.debug('Inserted questions: ' + questionsToInsert.size());
System.debug('Manifest success: ' + String.valueOf(manifestResult != null ? manifestResult.success : false));
