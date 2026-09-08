/**
 * ClientServiceSummaryController
 *
 * Backend for the clientServiceSummary LWC. Lets a Case Manager generate a
 * "Client Service Summary" PDF (interactions, benefits, and goal progress for
 * a Client over a date range) from either the Case or the Account record page.
 * The heavy lifting (querying, rendering, PDF conversion, upload) happens in
 * the docgen service; this class only resolves the Client/Case and relays
 * the request.
 */
public with sharing class ClientServiceSummaryController {

    private static final String DOCGEN_ENDPOINT = 'https://docgen.aritasconsulting.com/generate-client-service-summary';

    public class SummaryResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String error;
        @AuraEnabled public String contentDocumentId;
        @AuraEnabled public String downloadUrl;
        @AuraEnabled public String filename;
    }

    @AuraEnabled
    public static SummaryResult generate(Id recordId, String objectApiName, Date startDate, Date endDate) {
        SummaryResult result = new SummaryResult();
        try {
            if (recordId == null) {
                throw new AuraHandledException('A record is required.');
            }
            if (startDate == null) {
                throw new AuraHandledException('A start date is required.');
            }
            Date effectiveEndDate = endDate != null ? endDate : System.today();
            if (startDate > effectiveEndDate) {
                throw new AuraHandledException('The start date must be before the end date.');
            }

            Id accountId;
            Id caseId;
            if (objectApiName == 'Case') {
                caseId = recordId;
                List<Case> cases = [SELECT AccountId FROM Case WHERE Id = :recordId LIMIT 1];
                if (!cases.isEmpty()) {
                    accountId = cases[0].AccountId;
                }
            } else {
                accountId = recordId;
                List<Case> cases = [
                    SELECT Id FROM Case WHERE AccountId = :recordId ORDER BY CreatedDate DESC LIMIT 1
                ];
                if (!cases.isEmpty()) {
                    caseId = cases[0].Id;
                }
            }
            if (accountId == null) {
                throw new AuraHandledException('Could not resolve a Client account for this record.');
            }

            Map<String, Object> payload = new Map<String, Object>{
                'account_id' => accountId,
                'case_id'    => caseId,
                'start_date' => isoDate(startDate),
                'end_date'   => isoDate(effectiveEndDate)
            };

            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint(DOCGEN_ENDPOINT);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setTimeout(120000);
            httpReq.setBody(JSON.serialize(payload));

            HttpResponse res = new Http().send(httpReq);
            if (res.getStatusCode() == 200) {
                Map<String, Object> docData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                result.success = true;
                result.contentDocumentId = (String) docData.get('contentDocumentId');
                result.downloadUrl = (String) docData.get('downloadUrl');
                result.filename = (String) docData.get('filename');
            } else {
                result.success = false;
                result.error = 'Document service returned HTTP ' + res.getStatusCode() + ': ' + res.getBody().abbreviate(300);
            }
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            result.success = false;
            result.error = e.getMessage();
        }
        return result;
    }

    private static String isoDate(Date d) {
        return String.valueOf(d.year()) + '-' + pad(d.month()) + '-' + pad(d.day());
    }

    private static String pad(Integer n) {
        return n < 10 ? '0' + n : String.valueOf(n);
    }
}
