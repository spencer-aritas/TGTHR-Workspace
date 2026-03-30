/**
 * IncidentReportController
 *
 * Backend for the newIncidentReportCard LWC.
 * Replaces the New_Incident_Report Salesforce Flow with a pure LWC + Apex approach.
 *
 * Flow:
 *  1. LWC calls createIncidentReport() with form data as JSON
 *  2. Apex creates PublicComplaint with IncidentDate + Incident_Time__c
 *  3. Apex calls DocGenService /trigger-doc with the record ID
 *  4. Returns the generated ContentDocumentId + download URL to the LWC
 */
public with sharing class IncidentReportController {

    // ─── DTOs ──────────────────────────────────────────────────────────────────

    public class IncidentRequest {
        @AuraEnabled public String accountId;
        @AuraEnabled public String incidentType;      // ComplaintType picklist value
        @AuraEnabled public String incidentTypeLabel; // Display label for auto-generated subject
        @AuraEnabled public String description;
        @AuraEnabled public String incidentDate;      // ISO "YYYY-MM-DD"
        @AuraEnabled public String incidentTime;      // "HH:MM" from lightning-input type=time
        @AuraEnabled public String otherStaffPresent;
    }

    public class IncidentResult {
        @AuraEnabled public String  recordId;
        @AuraEnabled public String  contentDocumentId;
        @AuraEnabled public String  downloadUrl;
        @AuraEnabled public Boolean docGenSuccess;
        @AuraEnabled public String  docGenError;
    }

    // ─── Public API ────────────────────────────────────────────────────────────

    /**
     * Return ComplaintType picklist values as label/value pairs for a combobox.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getComplaintTypes() {
        try {
            Schema.DescribeFieldResult field = Schema.getGlobalDescribe()
                .get('PublicComplaint')
                .getDescribe()
                .fields.getMap()
                .get('ComplaintType')
                .getDescribe();

            List<Map<String, String>> options = new List<Map<String, String>>();
            for (Schema.PicklistEntry entry : field.getPicklistValues()) {
                if (entry.isActive()) {
                    options.add(new Map<String, String>{
                        'label' => entry.getLabel(),
                        'value' => entry.getValue()
                    });
                }
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to load incident types: ' + e.getMessage());
        }
    }

    /**
     * Create a PublicComplaint record and trigger document generation.
     */
    @AuraEnabled
    public static IncidentResult createIncidentReport(String requestJson) {
        try {
            IncidentRequest req = (IncidentRequest) JSON.deserialize(requestJson, IncidentRequest.class);

            // Validate
            if (String.isBlank(req.accountId))    throw new AuraHandledException('Participant is required.');
            if (String.isBlank(req.incidentType)) throw new AuraHandledException('Incident Type is required.');
            if (String.isBlank(req.incidentTime)) throw new AuraHandledException('Incident Time is required.');

            // Parse date
            Date incDate = String.isNotBlank(req.incidentDate)
                ? parseDateString(req.incidentDate)
                : System.today();

            // Parse time ("HH:MM" → Apex Time)
            Time incTime = null;
            if (String.isNotBlank(req.incidentTime)) {
                try {
                    List<String> parts = req.incidentTime.split(':');
                    Integer hour   = Integer.valueOf(parts[0]);
                    Integer minute = parts.size() > 1 ? Integer.valueOf(parts[1]) : 0;
                    incTime = Time.newInstance(hour, minute, 0, 0);
                } catch (Exception e) {
                    System.debug('IncidentReportController: could not parse time "' + req.incidentTime + '": ' + e.getMessage());
                }
            }

            // Look up participant last name for auto-generated subject
            Id accId = (Id) req.accountId;
            List<SObject> accts = Database.query('SELECT Id, LastName FROM Account WHERE Id = :accId LIMIT 1');
            String lastName = (!accts.isEmpty() && accts[0].get('LastName') != null)
                ? (String) accts[0].get('LastName')
                : 'Unknown';

            // Auto-generate subject: "LastName - IncidentType - MM/DD/YYYY"
            String typeLabel = String.isNotBlank(req.incidentTypeLabel) ? req.incidentTypeLabel : req.incidentType;
            String subject   = (lastName + ' - ' + typeLabel + ' - ' + formatDateMMDDYYYY(incDate)).left(255);

            // Build PublicComplaint dynamically (NPC managed object)
            Schema.SObjectType sType = Schema.getGlobalDescribe().get('PublicComplaint');
            if (sType == null) throw new AuraHandledException('PublicComplaint object not accessible. Check object permissions.');
            Map<String, Schema.SObjectField> fields = sType.getDescribe().fields.getMap();

            SObject complaint = sType.newSObject();
            complaint.put('AccountId',     accId);
            complaint.put('Subject',       subject);
            complaint.put('ComplaintType', req.incidentType);
            if (String.isNotBlank(req.description)) complaint.put('Description', req.description);
            if (fields.containsKey('incidentdate'))                        complaint.put('IncidentDate',     incDate);
            if (fields.containsKey('incident_time__c') && incTime != null) complaint.put('Incident_Time__c', incTime);
            if (fields.containsKey('other_staff_present__c') && String.isNotBlank(req.otherStaffPresent)) {
                complaint.put('Other_Staff_Present__c', req.otherStaffPresent.left(250));
            }

            try {
                insert complaint;
            } catch (DmlException dme) {
                throw new AuraHandledException('Failed to save incident report: ' + dme.getDmlMessage(0));
            }

            IncidentResult result = new IncidentResult();
            result.recordId = complaint.Id;
            return result;

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            System.debug('IncidentReportController.createIncidentReport unexpected error: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Unexpected error: ' + e.getMessage());
        }
    }

    /**
     * Trigger document generation for an existing PublicComplaint.
     * Called from LWC in a SEPARATE Apex transaction after createIncidentReport()
     * to avoid the Salesforce callout-after-DML restriction.
     */
    @AuraEnabled
    public static IncidentResult triggerDocGen(String recordId) {
        IncidentResult result = new IncidentResult();
        result.recordId = recordId;
        try {
            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint('https://docgen.aritasconsulting.com/trigger-doc');
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setTimeout(30000);
            httpReq.setBody(JSON.serialize(new Map<String, String>{
                'object_name' => 'PublicComplaint',
                'record_id'   => recordId
            }));

            HttpResponse res = new Http().send(httpReq);

            if (res.getStatusCode() == 200) {
                Map<String, Object> docData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                result.contentDocumentId = (String) docData.get('contentDocumentId');
                result.downloadUrl       = (String) docData.get('downloadUrl');
                result.docGenSuccess     = true;
            } else {
                result.docGenSuccess = false;
                result.docGenError   = 'DocGen service returned HTTP ' + res.getStatusCode() + ': ' + res.getBody().abbreviate(300);
            }
        } catch (Exception e) {
            result.docGenSuccess = false;
            result.docGenError   = e.getMessage();
            System.debug('IncidentReportController: docgen callout failed: ' + e.getMessage());
        }
        return result;
    }

    // ─── Helpers ───────────────────────────────────────────────────────────────

    private static Date parseDateString(String dateStr) {
        try {
            List<String> parts = dateStr.split('-');
            return Date.newInstance(Integer.valueOf(parts[0]), Integer.valueOf(parts[1]), Integer.valueOf(parts[2]));
        } catch (Exception e) {
            System.debug('IncidentReportController: could not parse date "' + dateStr + '", using today');
            return System.today();
        }
    }

    private static String formatDateMMDDYYYY(Date d) {
        Integer m = d.month(), dy = d.day(), yr = d.year();
        return (m  < 10 ? '0' : '') + m  + '/'
             + (dy < 10 ? '0' : '') + dy + '/' + yr;
    }
}
