public with sharing class BillingExportController {

    // ── Filter criteria from the UI ──
    public class ExportFilter {
        public Date startDate;
        public Date endDate;
        public Id providerId;          // OwnerId / CreatedById on InteractionSummary
        public String billingStatus;   // Draft, Submitted, Paid, etc.
        public String noteType;        // InteractionPurpose value
        public String interactionStatus; // Completed, Recalled, etc.
        public Integer limitRows;      // optional cap
    }

    // ── One flattened row per Interaction Service Line ──
    public class ExportRow {
        // Client
        @AuraEnabled public String clientName;
        @AuraEnabled public String clientId;

        // Case
        @AuraEnabled public String caseNumber;
        @AuraEnabled public Id caseId;

        // Interaction Summary (the note)
        @AuraEnabled public Id interactionSummaryId;
        @AuraEnabled public String noteName;
        @AuraEnabled public String noteType;
        @AuraEnabled public String noteStatus;
        @AuraEnabled public Date serviceDate;
        @AuraEnabled public DateTime startTime;
        @AuraEnabled public DateTime endTime;
        @AuraEnabled public String placeOfService;
        @AuraEnabled public Boolean interpreterUsed;

        // Provider
        @AuraEnabled public String providerName;
        @AuraEnabled public Id providerId;

        // Visit Details (SOAP)
        @AuraEnabled public String reasonForVisit;
        @AuraEnabled public String descriptionOfServices;
        @AuraEnabled public String responseAndProgress;
        @AuraEnabled public String planText;

        // Service Line (CPT)
        @AuraEnabled public Id serviceLineId;
        @AuraEnabled public String serviceLineName;
        @AuraEnabled public String cptCode;
        @AuraEnabled public Decimal units;
        @AuraEnabled public Decimal durationMinutes;
        @AuraEnabled public String billingStatus;
        @AuraEnabled public String modifier1;
        @AuraEnabled public String modifier2;

        // Diagnoses (semicolon-delimited)
        @AuraEnabled public String diagnosisCodes;
        @AuraEnabled public String diagnosisDescriptions;

        // Goals Addressed (semicolon-delimited)
        @AuraEnabled public String goalsAddressed;

        // Signature / Completion
        @AuraEnabled public DateTime completedOn;
        @AuraEnabled public Boolean managerSigned;
        @AuraEnabled public Date managerSignedDate;
        @AuraEnabled public Boolean requiresManagerApproval;

        // PDF
        @AuraEnabled public String pdfFileId;
        @AuraEnabled public String pdfTitle;

        // Benefits (semicolon-delimited)
        @AuraEnabled public String benefitNames;
    }

    // ── Demographic addendum row (deduplicated by Account) ──
    public class DemographicRow {
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public Date birthday;
        @AuraEnabled public String address;
        @AuraEnabled public Id salesforceAccountId;
        @AuraEnabled public String medicaidId;
    }

    // ── Picklist options for filter dropdowns ──
    public class FilterOptions {
        @AuraEnabled public List<PicklistEntry> billingStatuses;
        @AuraEnabled public List<PicklistEntry> noteTypes;
        @AuraEnabled public List<PicklistEntry> interactionStatuses;
        @AuraEnabled public List<LookupOption> providers;
    }

    public class PicklistEntry {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public PicklistEntry(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class LookupOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public LookupOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    // ── Load picklist options for the filter panel ──
    @AuraEnabled(cacheable=true)
    public static FilterOptions getFilterOptions() {
        FilterOptions opts = new FilterOptions();

        Map<String, Schema.SObjectField> slFields = Schema.SObjectType.Interaction_Service_Line__c.fields.getMap();
        Map<String, Schema.SObjectField> isFields = Schema.SObjectType.InteractionSummary.fields.getMap();

        // Billing Status picklist from Interaction_Service_Line__c
        opts.billingStatuses = new List<PicklistEntry>();
        for (Schema.PicklistEntry pe : slFields.get('Billing_Status__c').getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                opts.billingStatuses.add(new PicklistEntry(pe.getLabel(), pe.getValue()));
            }
        }

        // Note Types from InteractionSummary.InteractionPurpose
        opts.noteTypes = new List<PicklistEntry>();
        for (Schema.PicklistEntry pe : isFields.get('InteractionPurpose').getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                opts.noteTypes.add(new PicklistEntry(pe.getLabel(), pe.getValue()));
            }
        }

        // Interaction statuses
        opts.interactionStatuses = new List<PicklistEntry>();
        for (Schema.PicklistEntry pe : isFields.get('Status').getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                opts.interactionStatuses.add(new PicklistEntry(pe.getLabel(), pe.getValue()));
            }
        }

        // Providers: users who own at least one InteractionSummary
        opts.providers = new List<LookupOption>();
        for (AggregateResult ar : [
            SELECT OwnerId ownId, Owner.Name ownerName
            FROM InteractionSummary
            WHERE OwnerId != null
            GROUP BY OwnerId, Owner.Name
            ORDER BY Owner.Name
            LIMIT 200
        ]) {
            opts.providers.add(new LookupOption(
                (String) ar.get('ownerName'),
                (String) ar.get('ownId')
            ));
        }

        return opts;
    }

    // ── Main export query ──
    @AuraEnabled
    public static List<ExportRow> getExportData(String filterJson) {
        ExportFilter filter = (ExportFilter) JSON.deserialize(filterJson, ExportFilter.class);

        // Build dynamic SOQL for the service-line-centric query
        String query = 'SELECT Id, Name, Service_Code__c, Units__c, Duration_Minutes__c, '
            + 'Billing_Status__c, Modifier_1__c, Modifier_2__c, Service_Date__c, '
            + 'Interaction_Summary__c, '
            + 'Interaction_Summary__r.Name, '
            + 'Interaction_Summary__r.InteractionPurpose, '
            + 'Interaction_Summary__r.Status, '
            + 'Interaction_Summary__r.Start_Time__c, '
            + 'Interaction_Summary__r.End_Time__c, '
            + 'Interaction_Summary__r.POS__c, '
            + 'Interaction_Summary__r.Interpreter_Used__c, '
            + 'Interaction_Summary__r.MeetingNotes, '
            + 'Interaction_Summary__r.Description_of_Services__c, '
            + 'Interaction_Summary__r.Response_and_Progress__c, '
            + 'Interaction_Summary__r.Plan__c, '
            + 'Interaction_Summary__r.Completed_On__c, '
            + 'Interaction_Summary__r.Manager_Signed__c, '
            + 'Interaction_Summary__r.Manager_Signed_Date__c, '
            + 'Interaction_Summary__r.Requires_Manager_Approval__c, '
            + 'Interaction_Summary__r.PDF_File_Id__c, '
            + 'Interaction_Summary__r.OwnerId, '
            + 'Interaction_Summary__r.Owner.Name, '
            + 'Interaction_Summary__r.AccountId, '
            + 'Interaction_Summary__r.Account.Name, '
            + 'Interaction_Summary__r.RelatedRecordId '
            + 'FROM Interaction_Service_Line__c';

        List<String> conditions = new List<String>();
        List<Object> binds = new List<Object>();

        if (filter.startDate != null) {
            conditions.add('Service_Date__c >= :startDate');
        }
        if (filter.endDate != null) {
            conditions.add('Service_Date__c <= :endDate');
        }
        if (filter.providerId != null) {
            conditions.add('Interaction_Summary__r.OwnerId = :providerId');
        }
        if (String.isNotBlank(filter.billingStatus)) {
            conditions.add('Billing_Status__c = :billingStatus');
        }
        if (String.isNotBlank(filter.noteType)) {
            conditions.add('Interaction_Summary__r.InteractionPurpose = :noteType');
        }
        if (String.isNotBlank(filter.interactionStatus)) {
            conditions.add('Interaction_Summary__r.Status = :interactionStatus');
        }

        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }

        query += ' ORDER BY Service_Date__c DESC, Interaction_Summary__r.Name';

        Integer rowLimit = (filter.limitRows != null && filter.limitRows > 0)
            ? Math.min(filter.limitRows, 10000) : 2000;
        query += ' LIMIT ' + rowLimit;

        // Execute with bind variables
        Date startDate = filter.startDate;
        Date endDate = filter.endDate;
        Id providerId = filter.providerId;
        String billingStatus = filter.billingStatus;
        String noteType = filter.noteType;
        String interactionStatus = filter.interactionStatus;

        List<Interaction_Service_Line__c> serviceLines = Database.query(query);

        // Collect InteractionSummary IDs for related-object batch queries
        Set<Id> summaryIds = new Set<Id>();
        Set<String> pdfDocIds = new Set<String>();
        Set<Id> caseIds = new Set<Id>();
        for (Interaction_Service_Line__c sl : serviceLines) {
            summaryIds.add(sl.Interaction_Summary__c);
            if (String.isNotBlank(sl.Interaction_Summary__r.PDF_File_Id__c)) {
                pdfDocIds.add(sl.Interaction_Summary__r.PDF_File_Id__c);
            }
            if (sl.Interaction_Summary__r.RelatedRecordId != null) {
                String prefix = String.valueOf(sl.Interaction_Summary__r.RelatedRecordId).substring(0, 3);
                if (prefix == '500') { // Case prefix
                    caseIds.add(sl.Interaction_Summary__r.RelatedRecordId);
                }
            }
        }

        // Diagnoses by InteractionSummary (via Diagnosis_Note_Link__c)
        Map<Id, List<String>> diagCodesBySummary = new Map<Id, List<String>>();
        Map<Id, List<String>> diagDescsBySummary = new Map<Id, List<String>>();
        if (!summaryIds.isEmpty()) {
            for (Diagnosis_Note_Link__c dnl : [
                SELECT InteractionSummary__c, Diagnosis__r.ICD10Code__c, Diagnosis__r.Description__c
                FROM Diagnosis_Note_Link__c
                WHERE InteractionSummary__c IN :summaryIds
                ORDER BY Diagnosis__r.ICD10Code__c
            ]) {
                Id sid = dnl.InteractionSummary__c;
                if (!diagCodesBySummary.containsKey(sid)) {
                    diagCodesBySummary.put(sid, new List<String>());
                    diagDescsBySummary.put(sid, new List<String>());
                }
                String diagCode = dnl.Diagnosis__r.ICD10Code__c;
                String diagDesc = dnl.Diagnosis__r.Description__c;
                diagCodesBySummary.get(sid).add(diagCode != null ? diagCode : '');
                diagDescsBySummary.get(sid).add(diagDesc != null ? diagDesc : '');
            }
        }

        // Goals Addressed by InteractionSummary (via GoalAssignmentDetail)
        Map<Id, List<String>> goalsBySummary = new Map<Id, List<String>>();
        if (!summaryIds.isEmpty()) {
            for (GoalAssignmentDetail gad : [
                SELECT InteractionSummary__c,
                       GoalAssignment.Goal_Name__c,
                       GoalAssignment.CustomGoalName
                FROM GoalAssignmentDetail
                WHERE InteractionSummary__c IN :summaryIds
                ORDER BY GoalAssignment.Goal_Name__c
            ]) {
                Id sid = gad.InteractionSummary__c;
                if (!goalsBySummary.containsKey(sid)) {
                    goalsBySummary.put(sid, new List<String>());
                }
                String gName = String.isNotBlank(gad.GoalAssignment.Goal_Name__c)
                    ? gad.GoalAssignment.Goal_Name__c
                    : gad.GoalAssignment.CustomGoalName;
                goalsBySummary.get(sid).add(gName != null ? gName : '');
            }
        }

        // Benefits by InteractionSummary (via BenefitDisbursement → BenefitAssignment → Benefit)
        Map<Id, List<String>> benefitsBySummary = new Map<Id, List<String>>();
        if (!summaryIds.isEmpty()) {
            for (BenefitDisbursement bd : [
                SELECT InteractionSummary__c,
                       BenefitAssignment.Benefit.Name
                FROM BenefitDisbursement
                WHERE InteractionSummary__c IN :summaryIds
                ORDER BY BenefitAssignment.Benefit.Name
            ]) {
                Id sid = bd.InteractionSummary__c;
                if (!benefitsBySummary.containsKey(sid)) {
                    benefitsBySummary.put(sid, new List<String>());
                }
                String bName = (bd.BenefitAssignment != null && bd.BenefitAssignment.Benefit != null)
                    ? bd.BenefitAssignment.Benefit.Name : null;
                benefitsBySummary.get(sid).add(bName != null ? bName : '');
            }
        }

        // PDF titles
        Map<String, String> pdfTitles = new Map<String, String>();
        if (!pdfDocIds.isEmpty()) {
            for (ContentDocument cd : [
                SELECT Id, Title FROM ContentDocument WHERE Id IN :pdfDocIds
            ]) {
                pdfTitles.put(cd.Id, cd.Title);
            }
        }

        // Cases
        Map<Id, String> caseNumbers = new Map<Id, String>();
        if (!caseIds.isEmpty()) {
            for (Case c : [SELECT Id, CaseNumber FROM Case WHERE Id IN :caseIds]) {
                caseNumbers.put(c.Id, c.CaseNumber);
            }
        }

        // Assemble rows
        List<ExportRow> rows = new List<ExportRow>();
        for (Interaction_Service_Line__c sl : serviceLines) {
            InteractionSummary summary = sl.Interaction_Summary__r;
            ExportRow row = new ExportRow();

            // Client
            row.clientName = (summary.Account != null) ? summary.Account.Name : null;
            row.clientId = summary.AccountId;

            // Case
            Id relatedId = summary.RelatedRecordId;
            if (relatedId != null && caseNumbers.containsKey(relatedId)) {
                row.caseNumber = caseNumbers.get(relatedId);
                row.caseId = relatedId;
            }

            // Note
            row.interactionSummaryId = sl.Interaction_Summary__c;
            row.noteName = summary.Name;
            row.noteType = summary.InteractionPurpose;
            row.noteStatus = summary.Status;
            row.serviceDate = sl.Service_Date__c;
            row.startTime = summary.Start_Time__c;
            row.endTime = summary.End_Time__c;
            row.placeOfService = summary.POS__c;
            row.interpreterUsed = summary.Interpreter_Used__c;

            // Provider
            row.providerName = (summary.Owner != null) ? summary.Owner.Name : null;
            row.providerId = summary.OwnerId;

            // SOAP (strip HTML for CSV)
            row.reasonForVisit = stripHtml(summary.MeetingNotes);
            row.descriptionOfServices = stripHtml(summary.Description_of_Services__c);
            row.responseAndProgress = stripHtml(summary.Response_and_Progress__c);
            row.planText = stripHtml(summary.Plan__c);

            // Service Line
            row.serviceLineId = sl.Id;
            row.serviceLineName = sl.Name;
            row.cptCode = sl.Service_Code__c;
            row.units = sl.Units__c;
            row.durationMinutes = sl.Duration_Minutes__c;
            row.billingStatus = sl.Billing_Status__c;
            row.modifier1 = sl.Modifier_1__c;
            row.modifier2 = sl.Modifier_2__c;

            // Diagnoses
            Id sid = sl.Interaction_Summary__c;
            if (diagCodesBySummary.containsKey(sid)) {
                row.diagnosisCodes = String.join(diagCodesBySummary.get(sid), '; ');
                row.diagnosisDescriptions = String.join(diagDescsBySummary.get(sid), '; ');
            }

            // Goals
            if (goalsBySummary.containsKey(sid)) {
                row.goalsAddressed = String.join(goalsBySummary.get(sid), '; ');
            }

            // Signature
            row.completedOn = summary.Completed_On__c;
            row.managerSigned = summary.Manager_Signed__c;
            row.managerSignedDate = summary.Manager_Signed_Date__c;
            row.requiresManagerApproval = summary.Requires_Manager_Approval__c;

            // PDF
            row.pdfFileId = summary.PDF_File_Id__c;
            if (String.isNotBlank(summary.PDF_File_Id__c) && pdfTitles.containsKey(summary.PDF_File_Id__c)) {
                row.pdfTitle = pdfTitles.get(summary.PDF_File_Id__c);
            }

            // Benefits
            if (benefitsBySummary.containsKey(sid)) {
                row.benefitNames = String.join(benefitsBySummary.get(sid), '; ');
            }

            rows.add(row);
        }
        return rows;
    }

    // ── Bulk update Billing Status ──
    @AuraEnabled
    public static void updateBillingStatus(List<Id> serviceLineIds, String newStatus) {
        if (serviceLineIds == null || serviceLineIds.isEmpty()) {
            throw new AuraHandledException('No service lines selected.');
        }
        if (String.isBlank(newStatus)) {
            throw new AuraHandledException('Billing status is required.');
        }

        List<Interaction_Service_Line__c> toUpdate = new List<Interaction_Service_Line__c>();
        for (Id slId : serviceLineIds) {
            toUpdate.add(new Interaction_Service_Line__c(
                Id = slId,
                Billing_Status__c = newStatus
            ));
        }
        update toUpdate;
    }

    // ── Demographic addendum export data (deduplicated census) ──
    @AuraEnabled
    public static List<DemographicRow> getDemographicAddendum(List<Id> accountIds) {
        List<DemographicRow> rows = new List<DemographicRow>();
        if (accountIds == null || accountIds.isEmpty()) {
            return rows;
        }

        Set<Id> uniqueAccountIds = new Set<Id>();
        for (Id accountId : accountIds) {
            if (accountId != null) {
                uniqueAccountIds.add(accountId);
            }
        }
        if (uniqueAccountIds.isEmpty()) {
            return rows;
        }

        Map<String, Schema.SObjectField> accountFields = Schema.SObjectType.Account.fields.getMap();
        Boolean hasMedicaidField = accountFields.containsKey('MEDICAID_Number__pc');

        String accountQuery =
            'SELECT Id, Name, FirstName, LastName, PersonBirthdate, ' +
            'PersonMailingStreet, PersonMailingCity, PersonMailingState, PersonMailingPostalCode, PersonMailingCountry';
        if (hasMedicaidField) {
            accountQuery += ', MEDICAID_Number__pc';
        }
        accountQuery += ' FROM Account WHERE Id IN :uniqueAccountIds ORDER BY LastName, FirstName, Name';

        for (SObject acc : Database.query(accountQuery)) {
            DemographicRow row = new DemographicRow();
            String firstName = (String) acc.get('FirstName');
            String lastName = (String) acc.get('LastName');
            String fullName = (String) acc.get('Name');

            if (String.isBlank(firstName) && String.isBlank(lastName) && String.isNotBlank(fullName)) {
                List<String> parts = fullName.split(' ', 2);
                firstName = parts.isEmpty() ? null : parts[0];
                lastName = parts.size() > 1 ? parts[1] : null;
            }

            row.firstName = firstName;
            row.lastName = lastName;
            row.birthday = (Date) acc.get('PersonBirthdate');
            row.address = formatPersonMailingAddress(acc);
            row.salesforceAccountId = (Id) acc.get('Id');
            row.medicaidId = hasMedicaidField ? (String) acc.get('MEDICAID_Number__pc') : null;

            rows.add(row);
        }

        return rows;
    }

    // ── HTML → plain text for CSV export ──
    private static String stripHtml(String html) {
        if (String.isBlank(html)) return '';
        // Remove tags then collapse whitespace
        String text = html.replaceAll('<[^>]+>', ' ');
        text = text.replaceAll('&nbsp;', ' ');
        text = text.replaceAll('&amp;', '&');
        text = text.replaceAll('&lt;', '<');
        text = text.replaceAll('&gt;', '>');
        text = text.replaceAll('\\s+', ' ');
        return text.trim();
    }

    private static String formatPersonMailingAddress(SObject accountRecord) {
        List<String> parts = new List<String>();
        String street = (String) accountRecord.get('PersonMailingStreet');
        String city = (String) accountRecord.get('PersonMailingCity');
        String state = (String) accountRecord.get('PersonMailingState');
        String postalCode = (String) accountRecord.get('PersonMailingPostalCode');
        String country = (String) accountRecord.get('PersonMailingCountry');

        if (String.isNotBlank(street)) parts.add(street);
        if (String.isNotBlank(city)) parts.add(city);
        if (String.isNotBlank(state)) parts.add(state);
        if (String.isNotBlank(postalCode)) parts.add(postalCode);
        if (String.isNotBlank(country)) parts.add(country);

        return String.join(parts, ', ');
    }

    // ── Document content for PDF export ──
    // PDF_File_Id__c is the canonical pointer, stamped by docgen at generation time
    // (and re-stamped on recall/re-sign). If it's null, the upstream process failed
    // and we should surface that clearly rather than guessing.
    public class DocumentContent {
        @AuraEnabled public String contentDocumentId;
        @AuraEnabled public String fileName;
        @AuraEnabled public String base64Data;
    }

    @AuraEnabled
    public static DocumentContent getDocumentContent(String interactionSummaryId) {
        if (String.isBlank(interactionSummaryId)) {
            throw new AuraHandledException('Interaction Summary ID is required.');
        }

        List<InteractionSummary> summaries = [
            SELECT Id, PDF_File_Id__c, Name
            FROM InteractionSummary
            WHERE Id = :interactionSummaryId
            LIMIT 1
        ];
        if (summaries.isEmpty()) {
            throw new AuraHandledException('InteractionSummary not found: ' + interactionSummaryId);
        }

        InteractionSummary summary = summaries[0];
        if (String.isBlank(summary.PDF_File_Id__c)) {
            throw new AuraHandledException(
                'No PDF has been generated for "' + summary.Name + '". '
                + 'The document may need to be regenerated.'
            );
        }

        List<ContentVersion> versions = [
            SELECT Title, FileExtension, VersionData, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId = :summary.PDF_File_Id__c
              AND IsLatest = true
              AND PublishStatus = 'P'
            LIMIT 1
        ];

        if (versions.isEmpty()) {
            throw new AuraHandledException(
                'The PDF referenced by "' + summary.Name + '" (ContentDocument '
                + summary.PDF_File_Id__c + ') could not be retrieved. '
                + 'It may have been deleted or the document may need to be regenerated.'
            );
        }

        ContentVersion cv = versions[0];
        DocumentContent dc = new DocumentContent();
        dc.contentDocumentId = cv.ContentDocumentId;
        dc.fileName = cv.Title + '.' + (cv.FileExtension != null ? cv.FileExtension : 'pdf');
        dc.base64Data = EncodingUtil.base64Encode(cv.VersionData);
        return dc;
    }
}
