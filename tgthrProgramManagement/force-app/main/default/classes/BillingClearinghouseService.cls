public with sharing class BillingClearinghouseService {

    public class TransmissionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Integer statusCode;
        @AuraEnabled public String message;
        @AuraEnabled public String endpoint;
        @AuraEnabled public String transmissionId;
        @AuraEnabled public Id billingContentDocumentId;
        @AuraEnabled public Id demographicContentDocumentId;
        @AuraEnabled public Integer billingRowCount;
        @AuraEnabled public Integer demographicRowCount;
    }

    public class FlowRequest {
        @InvocableVariable(required=false)
        public String filterJson;
        @InvocableVariable(required=false)
        public String approvalReference;
    }

    public class FlowResult {
        @InvocableVariable
        public String queueJobId;
    }

    private class PackageContext {
        public String transmissionId;
        public String billingFileName;
        public String demographicFileName;
        public Blob billingBlob;
        public Blob demographicBlob;
        public Id billingContentDocumentId;
        public Id demographicContentDocumentId;
        public Integer billingRowCount;
        public Integer demographicRowCount;
    }

    @AuraEnabled
    public static String enqueueDispatch(String filterJson, String approvalReference) {
        return System.enqueueJob(new BillingClearinghouseDispatchJob(filterJson, approvalReference));
    }

    @InvocableMethod(label='Send Billing Package To Clearinghouse')
    public static List<FlowResult> enqueueDispatchFromFlow(List<FlowRequest> requests) {
        List<FlowResult> results = new List<FlowResult>();
        if (requests == null || requests.isEmpty()) {
            FlowResult emptyResult = new FlowResult();
            emptyResult.queueJobId = enqueueDispatch('{}', null);
            results.add(emptyResult);
            return results;
        }

        for (FlowRequest requestItem : requests) {
            FlowResult result = new FlowResult();
            String filterJson = requestItem != null ? requestItem.filterJson : null;
            String approvalReference = requestItem != null ? requestItem.approvalReference : null;
            result.queueJobId = enqueueDispatch(filterJson, approvalReference);
            results.add(result);
        }
        return results;
    }

    public static TransmissionResult dispatchNow(String filterJson, String approvalReference) {
        TransmissionResult result = new TransmissionResult();
        result.success = false;
        result.statusCode = 0;

        try {
            PackageContext packageCtx = buildAndStorePackage(filterJson);
            result.billingContentDocumentId = packageCtx.billingContentDocumentId;
            result.demographicContentDocumentId = packageCtx.demographicContentDocumentId;
            result.billingRowCount = packageCtx.billingRowCount;
            result.demographicRowCount = packageCtx.demographicRowCount;
            result.transmissionId = packageCtx.transmissionId;

            HttpRequest req = new HttpRequest();
            String endpoint = getClearinghouseEndpoint();
            result.endpoint = endpoint;
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000);

            Map<String, Object> payload = new Map<String, Object>{
                'transmissionId' => packageCtx.transmissionId,
                'approvalReference' => approvalReference,
                'source' => 'Salesforce',
                'generatedAt' => String.valueOf(System.now()),
                'files' => new List<Object>{
                    new Map<String, Object>{
                        'fileName' => packageCtx.billingFileName,
                        'contentType' => 'text/csv',
                        'base64Data' => EncodingUtil.base64Encode(packageCtx.billingBlob)
                    },
                    new Map<String, Object>{
                        'fileName' => packageCtx.demographicFileName,
                        'contentType' => 'text/csv',
                        'base64Data' => EncodingUtil.base64Encode(packageCtx.demographicBlob)
                    }
                }
            };

            req.setBody(JSON.serialize(payload));
            HttpResponse res = (new Http()).send(req);
            result.statusCode = res.getStatusCode();

            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                result.success = true;
                result.message = 'Clearinghouse accepted billing package.';
                safeAuditLog(
                    'BILLING_EXPORT_SFTP_SENT',
                    packageCtx.transmissionId,
                    'Billing package transmitted to clearinghouse endpoint. HTTP ' + res.getStatusCode(),
                    'BillingExport'
                );
            } else {
                result.message = 'Clearinghouse rejected package. HTTP ' + res.getStatusCode();
                safeAuditLog(
                    'BILLING_EXPORT_SFTP_FAILED',
                    packageCtx.transmissionId,
                    result.message,
                    'BillingExport'
                );
            }
        } catch (Exception ex) {
            result.success = false;
            result.message = 'Clearinghouse dispatch failed: ' + ex.getMessage();
            safeAuditLog(
                'BILLING_EXPORT_SFTP_FAILED',
                result.transmissionId,
                result.message,
                'BillingExport'
            );
        }

        return result;
    }

    private static PackageContext buildAndStorePackage(String filterJson) {
        String safeFilterJson = String.isBlank(filterJson) ? '{}' : filterJson;

        List<BillingExportController.ExportRow> exportRows = BillingExportController.getExportData(safeFilterJson);
        Set<Id> accountIds = new Set<Id>();
        for (BillingExportController.ExportRow row : exportRows) {
            if (String.isNotBlank(row.clientId)) {
                accountIds.add((Id) row.clientId);
            }
        }

        List<BillingExportController.DemographicRow> demographicRows =
            BillingExportController.getDemographicAddendum(new List<Id>(accountIds));

        Date today = Date.today();
        String billingFileName = 'billing_export_' + String.valueOf(today) + '.csv';
        String demographicFileName = 'billing_demographic_addendum_' + String.valueOf(today) + '.csv';
        String billingCsv = buildBillingCsv(exportRows);
        String demographicCsv = buildDemographicCsv(demographicRows);

        ContentVersion billingCv = new ContentVersion(
            Title = billingFileName.removeEnd('.csv'),
            PathOnClient = billingFileName,
            VersionData = Blob.valueOf(billingCsv)
        );
        ContentVersion demographicCv = new ContentVersion(
            Title = demographicFileName.removeEnd('.csv'),
            PathOnClient = demographicFileName,
            VersionData = Blob.valueOf(demographicCsv)
        );
        insert new List<ContentVersion>{ billingCv, demographicCv };

        Map<Id, ContentVersion> savedVersions = new Map<Id, ContentVersion>([
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id IN :new List<Id>{ billingCv.Id, demographicCv.Id }
        ]);

        String transmissionId = String.valueOf(Crypto.getRandomLong());
        safeAuditLog(
            'BILLING_EXPORT_PACKAGE_CREATED',
            transmissionId,
            'Created billing package CSVs. Billing rows=' + exportRows.size() + ', demographic rows=' + demographicRows.size(),
            'BillingExport'
        );

        PackageContext ctx = new PackageContext();
        ctx.transmissionId = transmissionId;
        ctx.billingFileName = billingFileName;
        ctx.demographicFileName = demographicFileName;
        ctx.billingBlob = Blob.valueOf(billingCsv);
        ctx.demographicBlob = Blob.valueOf(demographicCsv);
        ctx.billingContentDocumentId = savedVersions.get(billingCv.Id).ContentDocumentId;
        ctx.demographicContentDocumentId = savedVersions.get(demographicCv.Id).ContentDocumentId;
        ctx.billingRowCount = exportRows.size();
        ctx.demographicRowCount = demographicRows.size();
        return ctx;
    }

    private static String getClearinghouseEndpoint() {
        try {
            List<SObject> settings = Database.query(
                'SELECT Endpoint_URL__c FROM Clearinghouse_Settings__mdt WHERE Active__c = true LIMIT 1'
            );
            if (!settings.isEmpty()) {
                String endpoint = (String) settings[0].get('Endpoint_URL__c');
                if (String.isNotBlank(endpoint)) {
                    return endpoint;
                }
            }
        } catch (Exception ignored) {
            // Fall back to Named Credential alias
        }
        return 'callout:TGTHR_Clearinghouse/api/v1/billing/upload';
    }

    @TestVisible
    private static String buildBillingCsv(List<BillingExportController.ExportRow> rows) {
        List<String> lines = new List<String>{
            'Service Date,Client Name,Case Number,Note Type,Note Status,Provider,CPT Code,Service Line,Units,Duration (min),Billing Status,Modifier 1,Modifier 2,Diagnosis Codes,Diagnosis Descriptions,Goals Addressed,Reason for Visit,Description of Services,Response & Progress,Plan,Place of Service,Interpreter Used,Benefits,Completed On,Manager Signed,Manager Signed Date,PDF Title,Interaction Summary ID,Service Line ID'
        };

        if (rows == null) {
            return String.join(lines, '\n');
        }

        for (BillingExportController.ExportRow row : rows) {
            List<String> values = new List<String>{
                csvVal(row.serviceDate),
                csvVal(row.clientName),
                csvVal(row.caseNumber),
                csvVal(row.noteType),
                csvVal(row.noteStatus),
                csvVal(row.providerName),
                csvVal(row.cptCode),
                csvVal(row.serviceLineName),
                csvVal(row.units),
                csvVal(row.durationMinutes),
                csvVal(row.billingStatus),
                csvVal(row.modifier1),
                csvVal(row.modifier2),
                csvVal(row.diagnosisCodes),
                csvVal(row.diagnosisDescriptions),
                csvVal(row.goalsAddressed),
                csvVal(row.reasonForVisit),
                csvVal(row.descriptionOfServices),
                csvVal(row.responseAndProgress),
                csvVal(row.planText),
                csvVal(row.placeOfService),
                csvVal(row.interpreterUsed == true ? 'Yes' : 'No'),
                csvVal(row.benefitNames),
                csvVal(row.completedOn),
                csvVal(row.managerSigned == true ? 'Yes' : 'No'),
                csvVal(row.managerSignedDate),
                csvVal(row.pdfTitle),
                csvVal(row.interactionSummaryId),
                csvVal(row.serviceLineId)
            };
            lines.add(String.join(values, ','));
        }

        return String.join(lines, '\n');
    }

    @TestVisible
    private static String buildDemographicCsv(List<BillingExportController.DemographicRow> rows) {
        List<String> lines = new List<String>{
            'First Name,Last Name,Birthday,Address,Salesforce Account Id,Medicaid Id'
        };

        if (rows == null) {
            return String.join(lines, '\n');
        }

        for (BillingExportController.DemographicRow row : rows) {
            List<String> values = new List<String>{
                csvVal(row.firstName),
                csvVal(row.lastName),
                csvVal(row.birthday),
                csvVal(row.address),
                csvVal(row.salesforceAccountId),
                csvVal(row.medicaidId)
            };
            lines.add(String.join(values, ','));
        }

        return String.join(lines, '\n');
    }

    private static String csvVal(Object value) {
        if (value == null) {
            return '';
        }
        String str = String.valueOf(value);
        str = str.replace('"', '""');
        if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
            return '"' + str + '"';
        }
        return str;
    }

    private static void safeAuditLog(String actionType, String entityId, String details, String objectType) {
        try {
            AuditLogService.logAction(actionType, entityId, details, objectType);
        } catch (Exception ignored) {
            // Logging must not block billing export transmission.
        }
    }
}
