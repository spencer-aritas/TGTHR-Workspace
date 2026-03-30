// Rebuild the Drop-In and Outreach intake with a clean question set.
// Creates a new active template version on the existing template and retires prior active versions.

Id templateId = 'a0mRT000003THgTYAW';
Id approverId = '005VY000003VsDhYAK';
Id templateApprovalProgramId = '11WRT0000017pV32AI';

InterviewTemplate__c templateRecord = [
    SELECT Id, Name, Category__c, Active__c, Available_for_Mobile__c,
           Client_Signature_Policy__c, Staff_Signature_Policy__c,
           Allow_Benefits_Disbursement__c, Income_Benefits_Policy__c
    FROM InterviewTemplate__c
    WHERE Id = :templateId
    LIMIT 1
];

List<InterviewTemplateVersion__c> existingVersions = [
    SELECT Id, Name, Version__c, Status__c, Effective_From__c, Effective_To__c, Variant__c
    FROM InterviewTemplateVersion__c
    WHERE InterviewTemplate__c = :templateId
    ORDER BY Version__c DESC, CreatedDate DESC
];

Decimal nextVersionNumber = 1;
String variant = 'Housing';
List<InterviewTemplateVersion__c> versionsToRetire = new List<InterviewTemplateVersion__c>();

for (InterviewTemplateVersion__c versionRecord : existingVersions) {
    if (versionRecord.Version__c != null && versionRecord.Version__c >= nextVersionNumber) {
        nextVersionNumber = versionRecord.Version__c + 1;
    }
    if (String.isNotBlank(versionRecord.Variant__c)) {
        variant = versionRecord.Variant__c;
    }
    if (versionRecord.Status__c == 'Active') {
        versionRecord.Status__c = 'Retired';
        versionRecord.Effective_To__c = Date.today();
        versionsToRetire.add(versionRecord);
    }
}

if (!versionsToRetire.isEmpty()) {
    update versionsToRetire;
}

InterviewTemplateVersion__c newVersion = new InterviewTemplateVersion__c(
    InterviewTemplate__c = templateId,
    Name = 'Outreach Intake v' + String.valueOf(nextVersionNumber) + '.0',
    Version__c = nextVersionNumber,
    Status__c = 'Active',
    Variant__c = variant,
    Effective_From__c = Date.today(),
    Effective_To__c = null
);

insert newVersion;

List<Map<String, Object>> questionData = new List<Map<String, Object>>();
Integer orderCounter = 1;

questionData.add(new Map<String, Object>{
    'section' => 'Consent',
    'order' => orderCounter++,
    'label' => 'Documentation process and limits of confidentiality were explained.',
    'apiName' => 'Documentation_Offered__c',
    'responseType' => 'Boolean',
    'required' => true,
    'mapsTo' => 'Assessment__c.Documentation_Offered__c'
});
questionData.add(new Map<String, Object>{
    'section' => 'Consent',
    'order' => orderCounter++,
    'label' => 'Client verbally consented to complete the outreach intake.',
    'apiName' => 'Documentation_Consent__c',
    'responseType' => 'Boolean',
    'required' => true,
    'mapsTo' => 'Assessment__c.Documentation_Consent__c'
});
questionData.add(new Map<String, Object>{
    'section' => 'Consent',
    'order' => orderCounter++,
    'label' => 'Consent questions, concerns, or limits noted by the client',
    'apiName' => 'Outreach_Consent_Notes__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Presenting Needs',
    'order' => orderCounter++,
    'label' => 'What brought the client to drop-in or outreach services today?',
    'apiName' => 'presenting_problem_drop_in',
    'responseType' => 'Textarea',
    'required' => true
});
questionData.add(new Map<String, Object>{
    'section' => 'Presenting Needs',
    'order' => orderCounter++,
    'label' => 'Describe any immediate needs identified today.',
    'apiName' => 'immediate_needs',
    'responseType' => 'Textarea',
    'required' => true
});
questionData.add(new Map<String, Object>{
    'section' => 'Presenting Needs',
    'order' => orderCounter++,
    'label' => 'Requested services, supports, or referrals for this visit',
    'apiName' => 'Outreach_Service_Requests__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Communication and Identity',
    'order' => orderCounter++,
    'label' => 'Preferred spoken language',
    'apiName' => 'Outreach_Preferred_Language__c',
    'responseType' => 'Text',
    'required' => false
});
questionData.add(new Map<String, Object>{
    'section' => 'Communication and Identity',
    'order' => orderCounter++,
    'label' => 'Interpreter needed for services?',
    'apiName' => 'Outreach_Interpreter_Needed__c',
    'responseType' => 'Picklist',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes',
        'No',
        'Already arranged',
        'Unsure'
    })
});
questionData.add(new Map<String, Object>{
    'section' => 'Communication and Identity',
    'order' => orderCounter++,
    'label' => 'Cultural, community, or identity considerations the team should keep in mind',
    'apiName' => 'Outreach_Cultural_Identity_Notes__c',
    'responseType' => 'Textarea',
    'required' => false
});
questionData.add(new Map<String, Object>{
    'section' => 'Communication and Identity',
    'order' => orderCounter++,
    'label' => 'Immigration-related concerns affecting services or safety',
    'apiName' => 'Outreach_Immigration_Concerns__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Housing History',
    'order' => orderCounter++,
    'label' => 'Current living situation or where the client stayed last night',
    'apiName' => 'Outreach_Current_Living_Situation__c',
    'responseType' => 'Textarea',
    'required' => false
});
questionData.add(new Map<String, Object>{
    'section' => 'Housing History',
    'order' => orderCounter++,
    'label' => 'History of homelessness or housing instability',
    'apiName' => 'history_of_homelessness',
    'responseType' => 'Textarea',
    'required' => false
});
questionData.add(new Map<String, Object>{
    'section' => 'Housing History',
    'order' => orderCounter++,
    'label' => 'When did this current homelessness episode begin?',
    'apiName' => 'Homelessness_Episode_Start_Date__c',
    'responseType' => 'Date',
    'required' => false,
    'mapsTo' => 'Assessment__c.Homelessness_Episode_Start_Date__c'
});
questionData.add(new Map<String, Object>{
    'section' => 'Housing History',
    'order' => orderCounter++,
    'label' => 'How many times has the client experienced homelessness in the past 3 years?',
    'apiName' => 'Times_Homeless_Past_3_Years__c',
    'responseType' => 'Picklist',
    'required' => false,
    'mapsTo' => 'Assessment__c.Times_Homeless_Past_3_Years__c',
    'picklistValues' => JSON.serialize(new List<String>{
        'One time',
        'Two times',
        'Three times',
        'Four or more times',
        'Client Doesn\'t Know',
        'Prefers Not to Answer',
        'Data Not Collected'
    })
});
questionData.add(new Map<String, Object>{
    'section' => 'Housing History',
    'order' => orderCounter++,
    'label' => 'Total months homeless in the past 3 years',
    'apiName' => 'Total_Months_Homeless_Past_3_Years__c',
    'responseType' => 'Number',
    'required' => false,
    'mapsTo' => 'Assessment__c.Total_Months_Homeless_Past_3_Years__c'
});

questionData.add(new Map<String, Object>{
    'section' => 'Family and Social Support',
    'order' => orderCounter++,
    'label' => 'Family background, current family relationships, and caregiving dynamics',
    'apiName' => 'Family_Background__c',
    'responseType' => 'Textarea',
    'required' => false,
    'mapsTo' => 'Assessment__c.Family_Background__c'
});
questionData.add(new Map<String, Object>{
    'section' => 'Family and Social Support',
    'order' => orderCounter++,
    'label' => 'Current support system, safe contacts, and community supports',
    'apiName' => 'Support_System__c',
    'responseType' => 'Textarea',
    'required' => false,
    'mapsTo' => 'Assessment__c.Support_System__c'
});
questionData.add(new Map<String, Object>{
    'section' => 'Family and Social Support',
    'order' => orderCounter++,
    'label' => 'Pregnancy, parenting, or dependent-care considerations',
    'apiName' => 'Outreach_Pregnancy_Parenting_Notes__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental Health',
    'order' => orderCounter++,
    'label' => 'Current mental health concerns, symptoms, or emotional needs',
    'apiName' => 'Outreach_Mental_Health_Concerns__c',
    'responseType' => 'Textarea',
    'required' => false
});
questionData.add(new Map<String, Object>{
    'section' => 'Mental Health',
    'order' => orderCounter++,
    'label' => 'Counseling, therapy, or treatment history relevant to outreach planning',
    'apiName' => 'Counseling_History__c',
    'responseType' => 'Textarea',
    'required' => false,
    'mapsTo' => 'Assessment__c.Counseling_History__c'
});
questionData.add(new Map<String, Object>{
    'section' => 'Mental Health',
    'order' => orderCounter++,
    'label' => 'Current substance use, recovery status, or related concerns',
    'apiName' => 'Current_Substance_Use__c',
    'responseType' => 'Textarea',
    'required' => false,
    'mapsTo' => 'Assessment__c.Current_Substance_Use__c'
});

questionData.add(new Map<String, Object>{
    'section' => 'Physical Health',
    'order' => orderCounter++,
    'label' => 'Current health concerns, chronic conditions, or wellness needs',
    'apiName' => 'Current_Health_Concerns__c',
    'responseType' => 'Textarea',
    'required' => false,
    'mapsTo' => 'Assessment__c.Current_Health_Concerns__c'
});
questionData.add(new Map<String, Object>{
    'section' => 'Physical Health',
    'order' => orderCounter++,
    'label' => 'Is the client currently pregnant?',
    'apiName' => 'Pregnant__c',
    'responseType' => 'Picklist',
    'required' => false,
    'mapsTo' => 'Assessment__c.Pregnant__c',
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes',
        'No',
        'Client Doesn\'t Know',
        'Prefers Not to Answer',
        'Data Not Collected'
    })
});
questionData.add(new Map<String, Object>{
    'section' => 'Physical Health',
    'order' => orderCounter++,
    'label' => 'Primary medical, dental, medication, or provider-access needs',
    'apiName' => 'Outreach_Physical_Health_Needs__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Education and Vocation',
    'order' => orderCounter++,
    'label' => 'Education, GED, school, or training goals',
    'apiName' => 'Post_Secondary_Goals__c',
    'responseType' => 'Textarea',
    'required' => false,
    'mapsTo' => 'Assessment__c.Post_Secondary_Goals__c'
});
questionData.add(new Map<String, Object>{
    'section' => 'Education and Vocation',
    'order' => orderCounter++,
    'label' => 'Employment, vocational interests, and work barriers',
    'apiName' => 'Employment_Goals__c',
    'responseType' => 'Textarea',
    'required' => false,
    'mapsTo' => 'Assessment__c.Employment_Goals__c'
});

questionData.add(new Map<String, Object>{
    'section' => 'Financial and Benefits',
    'order' => orderCounter++,
    'label' => 'Income, money-management, or urgent financial concerns',
    'apiName' => 'Outreach_Financial_Concerns__c',
    'responseType' => 'Textarea',
    'required' => false
});
questionData.add(new Map<String, Object>{
    'section' => 'Financial and Benefits',
    'order' => orderCounter++,
    'label' => 'Benefits, insurance, or identification/documentation barriers',
    'apiName' => 'Outreach_Benefits_Documentation_Barriers__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Legal',
    'order' => orderCounter++,
    'label' => 'Legal history or justice-system involvement',
    'apiName' => 'Legal_History__c',
    'responseType' => 'Textarea',
    'required' => false,
    'mapsTo' => 'Assessment__c.Legal_History__c'
});
questionData.add(new Map<String, Object>{
    'section' => 'Legal',
    'order' => orderCounter++,
    'label' => 'Current legal status, probation/parole, warrants, or upcoming court needs',
    'apiName' => 'Current_Legal_Status__c',
    'responseType' => 'Textarea',
    'required' => false,
    'mapsTo' => 'Assessment__c.Current_Legal_Status__c'
});
questionData.add(new Map<String, Object>{
    'section' => 'Legal',
    'order' => orderCounter++,
    'label' => 'Legal advocacy or documentation needs',
    'apiName' => 'Legal_Needs__c',
    'responseType' => 'Textarea',
    'required' => false,
    'mapsTo' => 'Assessment__c.Legal_Needs__c'
});

questionData.add(new Map<String, Object>{
    'section' => 'Life Skills and Daily Living',
    'order' => orderCounter++,
    'label' => 'Daily living or independent living skill needs',
    'apiName' => 'Living_Concerns__c',
    'responseType' => 'Textarea',
    'required' => false,
    'mapsTo' => 'Assessment__c.Living_Concerns__c'
});
questionData.add(new Map<String, Object>{
    'section' => 'Life Skills and Daily Living',
    'order' => orderCounter++,
    'label' => 'Transportation, phone, technology, or access barriers',
    'apiName' => 'Outreach_Access_Barriers__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Safety and Risk',
    'order' => orderCounter++,
    'label' => 'Current safety concerns, risks, or protective factors',
    'apiName' => 'Risk_Safety_Notes__c',
    'responseType' => 'Textarea',
    'required' => false,
    'mapsTo' => 'Assessment__c.Risk_Safety_Notes__c'
});
questionData.add(new Map<String, Object>{
    'section' => 'Safety and Risk',
    'order' => orderCounter++,
    'label' => 'Safety planning needs or de-escalation strategies',
    'apiName' => 'Safety_Plan_Notes__c',
    'responseType' => 'Textarea',
    'required' => false,
    'mapsTo' => 'Assessment__c.Safety_Plan_Notes__c'
});

questionData.add(new Map<String, Object>{
    'section' => 'Strengths, Goals, and Interventions',
    'order' => orderCounter++,
    'label' => 'Strengths, assets, and resources the client brings',
    'apiName' => 'Strengths_Assets__c',
    'responseType' => 'Textarea',
    'required' => false,
    'mapsTo' => 'Assessment__c.Strengths_Assets__c'
});
questionData.add(new Map<String, Object>{
    'section' => 'Strengths, Goals, and Interventions',
    'order' => orderCounter++,
    'label' => 'Short-term goals, desired next steps, or requested outcomes',
    'apiName' => 'Outreach_Short_Term_Goals__c',
    'responseType' => 'Textarea',
    'required' => false
});
questionData.add(new Map<String, Object>{
    'section' => 'Strengths, Goals, and Interventions',
    'order' => orderCounter++,
    'label' => 'Interventions, action items, or engagement plan for this intake',
    'apiName' => 'Outreach_Interventions__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Checklist and Referrals',
    'order' => orderCounter++,
    'label' => 'Benefits screening or benefits navigation needed?',
    'apiName' => 'Outreach_Benefits_Screening_Needed__c',
    'responseType' => 'Picklist',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes',
        'No',
        'Maybe / follow up needed'
    })
});
questionData.add(new Map<String, Object>{
    'section' => 'Checklist and Referrals',
    'order' => orderCounter++,
    'label' => 'Documents or IDs the client needs to obtain, replace, or submit',
    'apiName' => 'Outreach_Documents_Needed__c',
    'responseType' => 'Textarea',
    'required' => false
});
questionData.add(new Map<String, Object>{
    'section' => 'Checklist and Referrals',
    'order' => orderCounter++,
    'label' => 'Referrals completed, pending referrals, or follow-up tasks',
    'apiName' => 'Outreach_Referral_Followup__c',
    'responseType' => 'Textarea',
    'required' => false
});
questionData.add(new Map<String, Object>{
    'section' => 'Checklist and Referrals',
    'order' => orderCounter++,
    'label' => 'Additional intake notes',
    'apiName' => 'Outreach_Additional_Notes__c',
    'responseType' => 'Textarea',
    'required' => false
});

List<InterviewQuestion__c> questionsToInsert = new List<InterviewQuestion__c>();
for (Map<String, Object> qMap : questionData) {
    InterviewQuestion__c questionRecord = new InterviewQuestion__c(
        InterviewTemplateVersion__c = newVersion.Id,
        Section__c = (String)qMap.get('section'),
        Order__c = (Integer)qMap.get('order'),
        Label__c = (String)qMap.get('label'),
        API_Name__c = (String)qMap.get('apiName'),
        Response_Type__c = (String)qMap.get('responseType'),
        Required__c = (Boolean)qMap.get('required'),
        Status__c = 'Active'
    );

    if (qMap.containsKey('mapsTo')) {
        questionRecord.Maps_To__c = (String)qMap.get('mapsTo');
    }
    if (qMap.containsKey('picklistValues')) {
        questionRecord.Picklist_Values__c = (String)qMap.get('picklistValues');
    }
    if (!qMap.containsKey('mapsTo')) {
        questionRecord.Approver__c = approverId;
    }

    questionsToInsert.add(questionRecord);
}

insert questionsToInsert;

List<TemplateApproval__c> existingApprovals = [
    SELECT Id, Status__c
    FROM TemplateApproval__c
    WHERE InterviewTemplate__c = :templateId
    LIMIT 1
];

if (existingApprovals.isEmpty()) {
    insert new TemplateApproval__c(
        InterviewTemplate__c = templateId,
        Status__c = 'Approved',
        Program__c = templateApprovalProgramId
    );
}

System.debug('Created Outreach template version: ' + newVersion.Id);
System.debug('Created Outreach questions: ' + questionsToInsert.size());
System.debug('Retired prior active versions: ' + versionsToRetire.size());