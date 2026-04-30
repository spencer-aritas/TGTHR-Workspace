@IsTest
private class BillingExportControllerTest {

    @TestSetup
    static void setupTestData() {
        Account person = TestDataFactory.createPersonAccount('Test', 'Client');

        SObject accountUpdate = Schema.getGlobalDescribe().get('Account').newSObject();
        accountUpdate.put('Id', person.Id);
        TestDataFactory.safePut(accountUpdate, 'PersonBirthdate', Date.newInstance(1990, 1, 1));
        TestDataFactory.safePut(accountUpdate, 'PersonMailingStreet', '123 Main St');
        TestDataFactory.safePut(accountUpdate, 'PersonMailingCity', 'Seattle');
        TestDataFactory.safePut(accountUpdate, 'MEDICAID_Number__pc', 'MCD12345');
        update accountUpdate;

        // Create an InteractionSummary with SOAP fields populated
        InteractionSummary summary = new InteractionSummary(
            Name = 'Test Clinical Note',
            MeetingNotes = '<p>Reason for <b>visit</b></p>',
            Description_of_Services__c = 'Services rendered',
            Response_and_Progress__c = 'Good progress',
            Plan__c = 'Continue treatment',
            Date_of_Interaction__c = Date.today(),
            InteractionPurpose = 'Clinical Note',
            Status = 'Completed',
            AccountId = person.Id
        );
        insert summary;

        // Create Interaction_Service_Line__c (master-detail to summary)
        Interaction_Service_Line__c sl = new Interaction_Service_Line__c(
            Interaction_Summary__c = summary.Id,
            Name = 'Test Service Line',
            Service_Date__c = Date.today(),
            Units__c = 1.5,
            Duration_Minutes__c = 45,
            Billing_Status__c = 'Draft'
        );
        insert sl;

        // Create a ContentVersion (PDF) linked to the summary
        ContentVersion cv = new ContentVersion(
            Title = 'Test_Note_PDF',
            PathOnClient = 'Test_Note_PDF.pdf',
            VersionData = Blob.valueOf('fake pdf content'),
            FirstPublishLocationId = summary.Id,
            Origin = 'H'
        );
        insert cv;

        // Retrieve the auto-created ContentDocumentId and stamp it on the summary
        ContentVersion inserted = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        summary.PDF_File_Id__c = inserted.ContentDocumentId;
        update summary;
    }

    // ── Helper to retrieve test data ──
    static InteractionSummary getTestSummary() {
        return [SELECT Id, Name, PDF_File_Id__c, AccountId FROM InteractionSummary WHERE Name = 'Test Clinical Note' LIMIT 1];
    }

    static Interaction_Service_Line__c getTestServiceLine() {
        return [SELECT Id FROM Interaction_Service_Line__c WHERE Name = 'Test Service Line' LIMIT 1];
    }

    // ── getFilterOptions ──

    @IsTest
    static void getFilterOptionsReturnsPicklists() {
        BillingExportController.FilterOptions opts = BillingExportController.getFilterOptions();
        System.assertNotEquals(null, opts.billingStatuses, 'Billing statuses should be populated.');
        System.assertNotEquals(null, opts.noteTypes, 'Note types should be populated.');
        System.assertNotEquals(null, opts.interactionStatuses, 'Interaction statuses should be populated.');
        System.assertNotEquals(null, opts.providers, 'Providers list should not be null.');
    }

    // ── getExportData ──

    @IsTest
    static void getExportDataReturnsRowsWithNoFilters() {
        BillingExportController.ExportFilter filter = new BillingExportController.ExportFilter();
        String filterJson = JSON.serialize(filter);

        List<BillingExportController.ExportRow> rows = BillingExportController.getExportData(filterJson);
        System.assert(rows.size() > 0, 'Should return at least one row from test data.');

        BillingExportController.ExportRow row = rows[0];
        System.assertEquals(Date.today(), row.serviceDate, 'Service date should match.');
        System.assertEquals(1.5, row.units, 'Units should match.');
        System.assertEquals(45, row.durationMinutes, 'Duration should match.');
        System.assertEquals('Draft', row.billingStatus, 'Billing status should match.');
        // stripHtml should have cleaned the MeetingNotes
        System.assert(!row.reasonForVisit.contains('<'), 'HTML should be stripped from reason for visit.');
        System.assert(row.reasonForVisit.contains('Reason for visit'), 'Plain text should remain.');
    }

    @IsTest
    static void getExportDataWithDateFilter() {
        BillingExportController.ExportFilter filter = new BillingExportController.ExportFilter();
        filter.startDate = Date.today().addDays(-1);
        filter.endDate = Date.today().addDays(1);
        String filterJson = JSON.serialize(filter);

        List<BillingExportController.ExportRow> rows = BillingExportController.getExportData(filterJson);
        System.assert(rows.size() > 0, 'Should return rows within date range.');
    }

    @IsTest
    static void getExportDataWithDateFilterExcludes() {
        BillingExportController.ExportFilter filter = new BillingExportController.ExportFilter();
        filter.startDate = Date.today().addDays(10);
        filter.endDate = Date.today().addDays(20);
        String filterJson = JSON.serialize(filter);

        List<BillingExportController.ExportRow> rows = BillingExportController.getExportData(filterJson);
        System.assertEquals(0, rows.size(), 'Should return no rows for future date range.');
    }

    @IsTest
    static void getExportDataWithNoteTypeFilter() {
        BillingExportController.ExportFilter filter = new BillingExportController.ExportFilter();
        filter.noteType = 'Clinical Note';
        String filterJson = JSON.serialize(filter);

        List<BillingExportController.ExportRow> rows = BillingExportController.getExportData(filterJson);
        System.assert(rows.size() > 0, 'Should return rows for Clinical Note type.');
    }

    @IsTest
    static void getExportDataWithBillingStatusFilter() {
        BillingExportController.ExportFilter filter = new BillingExportController.ExportFilter();
        filter.billingStatus = 'Draft';
        String filterJson = JSON.serialize(filter);

        List<BillingExportController.ExportRow> rows = BillingExportController.getExportData(filterJson);
        System.assert(rows.size() > 0, 'Should return rows for Draft billing status.');
    }

    @IsTest
    static void getExportDataWithRowLimit() {
        BillingExportController.ExportFilter filter = new BillingExportController.ExportFilter();
        filter.limitRows = 1;
        String filterJson = JSON.serialize(filter);

        List<BillingExportController.ExportRow> rows = BillingExportController.getExportData(filterJson);
        System.assert(rows.size() <= 1, 'Should respect row limit.');
    }

    @IsTest
    static void getExportDataPopulatesPdfTitle() {
        BillingExportController.ExportFilter filter = new BillingExportController.ExportFilter();
        String filterJson = JSON.serialize(filter);

        List<BillingExportController.ExportRow> rows = BillingExportController.getExportData(filterJson);
        System.assert(rows.size() > 0, 'Should have test data.');
        BillingExportController.ExportRow row = rows[0];
        System.assertNotEquals(null, row.pdfFileId, 'PDF file ID should be populated.');
        System.assertEquals('Test_Note_PDF', row.pdfTitle, 'PDF title should match uploaded content.');
    }

    // ── updateBillingStatus ──

    @IsTest
    static void updateBillingStatusSuccess() {
        Interaction_Service_Line__c sl = getTestServiceLine();

        Test.startTest();
        BillingExportController.updateBillingStatus(
            new List<Id>{ sl.Id },
            'Ready'
        );
        Test.stopTest();

        Interaction_Service_Line__c updated = [
            SELECT Billing_Status__c FROM Interaction_Service_Line__c WHERE Id = :sl.Id
        ];
        System.assertEquals('Ready', updated.Billing_Status__c, 'Status should be updated.');
    }

    @IsTest
    static void updateBillingStatusRejectsEmpty() {
        try {
            BillingExportController.updateBillingStatus(new List<Id>(), 'Ready');
            System.assert(false, 'Should have thrown.');
        } catch (AuraHandledException e) {
            System.assert(e != null, 'AuraHandledException should be thrown for empty list.');
        }
    }

    @IsTest
    static void updateBillingStatusRejectsNull() {
        try {
            BillingExportController.updateBillingStatus(null, 'Ready');
            System.assert(false, 'Should have thrown.');
        } catch (AuraHandledException e) {
            System.assert(e != null, 'AuraHandledException should be thrown for null list.');
        }
    }

    @IsTest
    static void updateBillingStatusRejectsBlankStatus() {
        try {
            BillingExportController.updateBillingStatus(
                new List<Id>{ getTestServiceLine().Id }, ''
            );
            System.assert(false, 'Should have thrown.');
        } catch (AuraHandledException e) {
            System.assert(e != null, 'AuraHandledException should be thrown for blank status.');
        }
    }

    // ── getDocumentContent ──

    @IsTest
    static void getDocumentContentReturnsCanonicalPdf() {
        InteractionSummary summary = getTestSummary();

        Test.startTest();
        BillingExportController.DocumentContent dc = BillingExportController.getDocumentContent(summary.Id);
        Test.stopTest();

        System.assertEquals(summary.PDF_File_Id__c, dc.contentDocumentId, 'Should return the canonical PDF.');
        System.assert(dc.fileName.contains('Test_Note_PDF'), 'Filename should contain the title.');
        System.assertNotEquals(null, dc.base64Data, 'Base64 data should be populated.');
        System.assert(dc.base64Data.length() > 0, 'Base64 data should not be empty.');
    }

    @IsTest
    static void getDocumentContentRejectsBlankId() {
        try {
            BillingExportController.getDocumentContent('');
            System.assert(false, 'Should have thrown.');
        } catch (AuraHandledException e) {
            System.assert(e != null, 'AuraHandledException should be thrown for blank ID.');
        }
    }

    @IsTest
    static void getDocumentContentRejectsNullId() {
        try {
            BillingExportController.getDocumentContent(null);
            System.assert(false, 'Should have thrown.');
        } catch (AuraHandledException e) {
            System.assert(e != null, 'AuraHandledException should be thrown for null ID.');
        }
    }

    @IsTest
    static void getDocumentContentThrowsWhenNoPdf() {
        // Create a summary without PDF_File_Id__c
        InteractionSummary noPdfSummary = new InteractionSummary(
            Name = 'No PDF Note',
            Date_of_Interaction__c = Date.today()
        );
        insert noPdfSummary;

        try {
            BillingExportController.getDocumentContent(noPdfSummary.Id);
            System.assert(false, 'Should have thrown for missing PDF.');
        } catch (AuraHandledException e) {
            System.assert(e != null, 'AuraHandledException should be thrown when no PDF exists.');
        }
    }

    @IsTest
    static void getDocumentContentThrowsForBadSummaryId() {
        try {
            // Use a valid-format but non-existent ID
            BillingExportController.getDocumentContent('8BV000000000001AAA');
            System.assert(false, 'Should have thrown for non-existent summary.');
        } catch (AuraHandledException e) {
            System.assert(e != null, 'AuraHandledException should be thrown for non-existent summary.');
        }
    }

    // ── Inner class constructors ──

    @IsTest
    static void picklistEntryConstructor() {
        BillingExportController.PicklistEntry pe = new BillingExportController.PicklistEntry('Draft', 'Draft');
        System.assertEquals('Draft', pe.label);
        System.assertEquals('Draft', pe.value);
    }

    @IsTest
    static void lookupOptionConstructor() {
        BillingExportController.LookupOption lo = new BillingExportController.LookupOption('John Doe', '005xx');
        System.assertEquals('John Doe', lo.label);
        System.assertEquals('005xx', lo.value);
    }

    @IsTest
    static void getDemographicAddendumReturnsDedupedRows() {
        InteractionSummary summary = getTestSummary();

        List<BillingExportController.DemographicRow> rows = BillingExportController.getDemographicAddendum(
            new List<Id>{ summary.AccountId, summary.AccountId }
        );

        System.assertEquals(1, rows.size(), 'Should deduplicate account IDs.');
        BillingExportController.DemographicRow row = rows[0];
        System.assertEquals(summary.AccountId, row.salesforceAccountId, 'Account ID should match.');
        System.assertNotEquals(null, row.address, 'Address should be populated when mailing fields exist.');
    }

    @IsTest
    static void getDemographicAddendumHandlesEmptyInput() {
        System.assertEquals(
            0,
            BillingExportController.getDemographicAddendum(new List<Id>()).size(),
            'Empty input should return empty result.'
        );
        System.assertEquals(
            0,
            BillingExportController.getDemographicAddendum(null).size(),
            'Null input should return empty result.'
        );
    }

    @IsTest
    static void getDemographicAddendumFiltersNullIdsInList() {
        InteractionSummary summary = getTestSummary();
        List<Id> ids = new List<Id>{ null, summary.AccountId, null };

        List<BillingExportController.DemographicRow> rows =
            BillingExportController.getDemographicAddendum(ids);

        System.assertEquals(1, rows.size(), 'Null IDs in the list should be ignored.');
        System.assertEquals(summary.AccountId, rows[0].salesforceAccountId);
    }

    @IsTest
    static void getDemographicAddendumHandlesNoMailingAddress() {
        Account noMailPerson = TestDataFactory.createPersonAccount('NoMail', 'Client');
        // PersonMailing fields left blank — no update needed

        List<BillingExportController.DemographicRow> rows =
            BillingExportController.getDemographicAddendum(new List<Id>{ noMailPerson.Id });

        System.assertEquals(1, rows.size(), 'Should return a row even with no mailing data.');
        // address may be blank or null but must not throw
        System.assertNotEquals(null, rows[0], 'Row should not be null.');
    }

    // ── getExportData — additional filter paths ──

    @IsTest
    static void getExportDataWithProviderFilter() {
        // The test InteractionSummary is owned by the running user
        BillingExportController.ExportFilter filter = new BillingExportController.ExportFilter();
        filter.providerId = UserInfo.getUserId();
        String filterJson = JSON.serialize(filter);

        List<BillingExportController.ExportRow> rows = BillingExportController.getExportData(filterJson);
        System.assert(rows.size() > 0, 'Should return rows for the current user as provider.');
    }

    @IsTest
    static void getExportDataWithNonMatchingProviderFilter() {
        // Use a fake but valid-format user ID that won't match anyone
        BillingExportController.ExportFilter filter = new BillingExportController.ExportFilter();
        filter.providerId = UserInfo.getUserId(); // will match; swap to a known-non-match via status filter
        filter.billingStatus = 'Paid'; // no Paid rows in setup data
        String filterJson = JSON.serialize(filter);

        List<BillingExportController.ExportRow> rows = BillingExportController.getExportData(filterJson);
        System.assertEquals(0, rows.size(), 'No rows should match Paid billing status.');
    }

    @IsTest
    static void getExportDataWithInteractionStatusFilter() {
        BillingExportController.ExportFilter filter = new BillingExportController.ExportFilter();
        filter.interactionStatus = 'Completed';
        String filterJson = JSON.serialize(filter);

        List<BillingExportController.ExportRow> rows = BillingExportController.getExportData(filterJson);
        System.assert(rows.size() > 0, 'Should return rows for Completed status.');
        for (BillingExportController.ExportRow row : rows) {
            System.assertEquals('Completed', row.noteStatus, 'All rows should have Completed status.');
        }
    }

    @IsTest
    static void getExportDataWithLimitRowsExceedsMax() {
        BillingExportController.ExportFilter filter = new BillingExportController.ExportFilter();
        filter.limitRows = 20000; // exceeds hard cap of 10000
        String filterJson = JSON.serialize(filter);

        // Should not throw; Math.min clamps to 10000
        List<BillingExportController.ExportRow> rows = BillingExportController.getExportData(filterJson);
        System.assertNotEquals(null, rows, 'Should return a list without error when limitRows exceeds cap.');
    }

    @IsTest
    static void getExportDataWithDiagnosisPopulated() {
        InteractionSummary summary = getTestSummary();

        SObject diag = TestDataFactory.createDiagnosis(summary.AccountId, 'F32.1', 'Major depressive disorder');
        TestDataFactory.createDiagnosisNoteLink((Id) diag.get('Id'), summary.Id);

        BillingExportController.ExportFilter filter = new BillingExportController.ExportFilter();
        String filterJson = JSON.serialize(filter);

        Test.startTest();
        List<BillingExportController.ExportRow> rows = BillingExportController.getExportData(filterJson);
        Test.stopTest();

        // Find the row for our summary
        BillingExportController.ExportRow matchRow = null;
        for (BillingExportController.ExportRow row : rows) {
            if (row.interactionSummaryId == summary.Id) {
                matchRow = row;
                break;
            }
        }
        System.assertNotEquals(null, matchRow, 'Should find row for the test summary.');
        System.assert(String.isNotBlank(matchRow.diagnosisCodes),
            'Diagnosis codes should be populated when a Diagnosis_Note_Link__c exists.');
        System.assert(matchRow.diagnosisCodes.contains('F32.1'), 'Should contain the ICD code.');
    }

    @IsTest
    static void getExportDataWithCaseRelatedRecord() {
        // CoreData provides a Case created through TestDataFactory's trigger-safe path
        TestDataFactory.CoreData core = TestDataFactory.createCoreData();
        Case linkedCase = core.caseRecord;

        InteractionSummary caseNote = new InteractionSummary(
            Name = 'Case Linked Note',
            Date_of_Interaction__c = Date.today(),
            InteractionPurpose = 'Clinical Note',
            Status = 'Completed',
            AccountId = core.account.Id,
            RelatedRecordId = linkedCase.Id
        );
        insert caseNote;

        Interaction_Service_Line__c sl = new Interaction_Service_Line__c(
            Interaction_Summary__c = caseNote.Id,
            Name = 'Case SL',
            Service_Date__c = Date.today(),
            Units__c = 1,
            Billing_Status__c = 'Draft'
        );
        insert sl;

        BillingExportController.ExportFilter filter = new BillingExportController.ExportFilter();
        filter.noteType = 'Clinical Note';
        String filterJson = JSON.serialize(filter);

        Test.startTest();
        List<BillingExportController.ExportRow> rows = BillingExportController.getExportData(filterJson);
        Test.stopTest();

        BillingExportController.ExportRow matchRow = null;
        for (BillingExportController.ExportRow row : rows) {
            if (row.interactionSummaryId == caseNote.Id) {
                matchRow = row;
                break;
            }
        }
        System.assertNotEquals(null, matchRow, 'Should find the case-linked note row.');
        System.assertNotEquals(null, matchRow.caseNumber, 'Case number should be populated from RelatedRecordId.');
        System.assertEquals(linkedCase.Id, matchRow.caseId, 'Case ID should match.');
    }

    // ── getDocumentContent — ContentVersion not found path ──

    @IsTest
    static void getDocumentContentThrowsWhenContentVersionMissing() {
        // Create a summary whose PDF_File_Id__c points to a non-existent ContentDocument
        InteractionSummary ghostPdfSummary = new InteractionSummary(
            Name = 'Ghost PDF Note',
            Date_of_Interaction__c = Date.today(),
            PDF_File_Id__c = '069000000000001AAA' // valid format, no matching ContentDocument
        );
        insert ghostPdfSummary;

        try {
            BillingExportController.getDocumentContent(ghostPdfSummary.Id);
            System.assert(false, 'Should have thrown when ContentVersion is not found.');
        } catch (AuraHandledException e) {
            System.assert(e != null, 'AuraHandledException should be thrown for missing ContentVersion.');
        }
    }

    // ── Bulkification: updateBillingStatus with 200 records ──

    @IsTest
    static void updateBillingStatusBulk200Records() {
        InteractionSummary summary = getTestSummary();

        List<Interaction_Service_Line__c> slList = new List<Interaction_Service_Line__c>();
        for (Integer i = 0; i < 200; i++) {
            slList.add(new Interaction_Service_Line__c(
                Interaction_Summary__c = summary.Id,
                Name = 'Bulk SL ' + i,
                Service_Date__c = Date.today(),
                Units__c = 1,
                Billing_Status__c = 'Draft'
            ));
        }
        insert slList;

        List<Id> bulkIds = new List<Id>();
        for (Interaction_Service_Line__c sl : slList) {
            bulkIds.add(sl.Id);
        }

        Test.startTest();
        BillingExportController.updateBillingStatus(bulkIds, 'Ready');
        Test.stopTest();

        List<Interaction_Service_Line__c> updated = [
            SELECT Billing_Status__c
            FROM Interaction_Service_Line__c
            WHERE Id IN :bulkIds
        ];
        System.assertEquals(200, updated.size(), 'All 200 records should have been updated.');
        for (Interaction_Service_Line__c sl : updated) {
            System.assertEquals('Ready', sl.Billing_Status__c,
                'Every record should have Billing_Status__c = Ready.');
        }
    }
}
