/**
 * TemplateApprovalService — Custom approval workflow for interview templates
 * 
 * Replaces Salesforce native approvals with a lightweight, custom object-based
 * approval system routed through Program Director.
 * 
 * Key Features:
 * - Submit templates for approval to Program Director
 * - Auto-approve templates with only library questions (no bespoke questions)
 * - Track approval history + audit trail
 * - Interoperable with TemplateLinterService (check 1 validates approvals)
 * 
 * Uses dynamic SOQL for custom object flexibility.
 */
public without sharing class TemplateApprovalService {
    
    // ========== DTOs ==========
    
    public class SubmitApprovalResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id approvalId;
        @AuraEnabled public String message;
        @AuraEnabled public String approverId;
        @AuraEnabled public String approverName;
        
        public SubmitApprovalResult(Boolean success, String message) {
            this.success = success;
            this.message = message;
        }
    }
    
    public class ApprovalSummary {
        @AuraEnabled public Id approvalId;
        @AuraEnabled public Id templateId;
        @AuraEnabled public String templateName;
        @AuraEnabled public String programName;
        @AuraEnabled public DateTime submittedDate;
        @AuraEnabled public String submittedByName;
        @AuraEnabled public Integer bespokenQuestionCount;
        
        public ApprovalSummary() {}
    }
    
    public class ApprovalHistoryItem {
        @AuraEnabled public Id approvalId;
        @AuraEnabled public String status;
        @AuraEnabled public DateTime submittedDate;
        @AuraEnabled public DateTime decidedDate;
        @AuraEnabled public String approverName;
        @AuraEnabled public String comments;
        @AuraEnabled public String rejectionReason;
        
        public ApprovalHistoryItem() {}
    }
    
    public class ApprovalActionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id templateId;
        @AuraEnabled public String newStatus;
        
        public ApprovalActionResult(Boolean success, String message) {
            this.success = success;
            this.message = message;
        }
    }
    
    // ========== Public API ==========
    
    /**
     * Submit template for approval to Program Director
     * Called after linter passes, manifest generated
     * 
     * Validates:
     * - Template exists
     * - Program has Program_Director__c set
     * - No pending approval already exists for this template
     */
    @AuraEnabled
    public static SubmitApprovalResult submitForApproval(
        Id templateId,
        String lintReportJson,
        String manifestJson,
        String templateVersion
    ) {
        try {
            if (templateId == null) {
                return new SubmitApprovalResult(false, 'Template ID required');
            }
            
            // Fetch template with program details
            String templateQuery = 'SELECT Id, Name, Program__c FROM InterviewTemplate__c WHERE Id = :templateId LIMIT 1';
            List<SObject> templates = Database.query(templateQuery);
            
            if (templates.isEmpty()) {
                return new SubmitApprovalResult(false, 'Template not found: ' + templateId);
            }
            
            SObject template = templates[0];
            Id programId = (Id)template.get('Program__c');
            String templateName = (String)template.get('Name');
            
            if (programId == null) {
                return new SubmitApprovalResult(false, 'Template must be linked to a Program');
            }
            
            // Fetch program with director
            String programQuery = 'SELECT Id, Name, Program_Director__c FROM Program WHERE Id = :programId LIMIT 1';
            List<SObject> programs = Database.query(programQuery);
            
            if (programs.isEmpty()) {
                return new SubmitApprovalResult(false, 'Program not found: ' + programId);
            }
            
            SObject program = programs[0];
            Id directorId = (Id)program.get('Program_Director__c');
            String programName = (String)program.get('Name');
            
            if (directorId == null) {
                return new SubmitApprovalResult(false, 'Program does not have a Program Director assigned');
            }
            
            // Check for existing pending approval
            String checkQuery = 'SELECT Id FROM TemplateApproval__c WHERE InterviewTemplate__c = :templateId AND Status__c = \'Pending\' LIMIT 1';
            List<SObject> existingApprovals = Database.query(checkQuery);
            
            if (!existingApprovals.isEmpty()) {
                return new SubmitApprovalResult(false, 'A pending approval already exists for this template');
            }
            
            // Create approval record
            SObject approval = (SObject)Type.forName('TemplateApproval__c').newInstance();
            approval.put('InterviewTemplate__c', templateId);
            approval.put('Program__c', programId);
            approval.put('Approver__c', directorId);
            approval.put('Submitted_By__c', UserInfo.getUserId());
            approval.put('Status__c', 'Pending');
            approval.put('Submitted_Date__c', DateTime.now());
            approval.put('Linter_Report__c', lintReportJson);
            approval.put('Mobile_Manifest__c', manifestJson);
            approval.put('Template_Version__c', templateVersion);
            
            Database.SaveResult sr = Database.insert(approval, false);
            
            if (!sr.isSuccess()) {
                String errorMsg = 'Failed to create approval';
                System.debug(errorMsg);
                return new SubmitApprovalResult(false, errorMsg);
            }
            
            // Fetch approver name
            String approverQuery = 'SELECT Id, Name FROM User WHERE Id = :directorId LIMIT 1';
            List<SObject> approvers = Database.query(approverQuery);
            String approverName = approvers.isEmpty() ? 'Unknown' : (String)approvers[0].get('Name');
            
            SubmitApprovalResult result = new SubmitApprovalResult(true, 'Template submitted to ' + approverName + ' for approval');
            result.approvalId = sr.getId();
            result.approverId = directorId;
            result.approverName = approverName;
            
            System.debug('Template ' + templateId + ' submitted for approval to ' + approverName);
            
            return result;
            
        } catch (Exception e) {
            System.debug('Error submitting for approval: ' + e.getMessage());
            return new SubmitApprovalResult(false, 'Error: ' + e.getMessage());
        }
    }
    
    /**
     * Get all pending approvals for current user (if Program Director)
     * Cacheable for LWC
     */
    @AuraEnabled(cacheable=true)
    public static List<ApprovalSummary> getPendingApprovalsForCurrentUser() {
        try {
            Id currentUserId = UserInfo.getUserId();
            List<ApprovalSummary> summaries = new List<ApprovalSummary>();
            
            // Query all pending approvals where current user is approver
            String query = 'SELECT Id, InterviewTemplate__c, InterviewTemplate__r.Name, ' +
                           'Program__c, Program__r.Name, Submitted_Date__c, Submitted_By__r.Name ' +
                           'FROM TemplateApproval__c ' +
                           'WHERE Approver__c = :currentUserId AND Status__c = \'Pending\' ' +
                           'ORDER BY Submitted_Date__c DESC LIMIT 100';
            
            List<SObject> approvals = Database.query(query);
            
            for (SObject approval : approvals) {
                ApprovalSummary summary = new ApprovalSummary();
                summary.approvalId = (Id)approval.get('Id');
                summary.templateId = (Id)approval.get('InterviewTemplate__c');
                summary.templateName = (String)approval.get('InterviewTemplate__r.Name');
                summary.programName = (String)approval.get('Program__r.Name');
                summary.submittedDate = (DateTime)approval.get('Submitted_Date__c');
                summary.submittedByName = (String)approval.get('Submitted_By__r.Name');
                
                // Count bespoke questions
                summary.bespokenQuestionCount = countBespokeQuestions((Id)approval.get('InterviewTemplate__c'));
                
                summaries.add(summary);
            }
            
            return summaries;
            
        } catch (Exception e) {
            System.debug('Error fetching pending approvals: ' + e.getMessage());
            return new List<ApprovalSummary>();
        }
    }
    
    /**
     * Get approval history for a template (all approvals, pending + resolved)
     */
    @AuraEnabled(cacheable=true)
    public static List<ApprovalHistoryItem> getApprovalHistory(Id templateId) {
        try {
            List<ApprovalHistoryItem> history = new List<ApprovalHistoryItem>();
            
            String query = 'SELECT Id, Status__c, Submitted_Date__c, Decision_Date__c, ' +
                           'Approver__r.Name, Comments__c, Rejection_Reason__c ' +
                           'FROM TemplateApproval__c ' +
                           'WHERE InterviewTemplate__c = :templateId ' +
                           'ORDER BY Submitted_Date__c DESC LIMIT 100';
            
            List<SObject> approvals = Database.query(query);
            
            for (SObject approval : approvals) {
                ApprovalHistoryItem item = new ApprovalHistoryItem();
                item.approvalId = (Id)approval.get('Id');
                item.status = (String)approval.get('Status__c');
                item.submittedDate = (DateTime)approval.get('Submitted_Date__c');
                item.decidedDate = (DateTime)approval.get('Decision_Date__c');
                item.approverName = (String)approval.get('Approver__r.Name');
                item.comments = (String)approval.get('Comments__c');
                item.rejectionReason = (String)approval.get('Rejection_Reason__c');
                
                history.add(item);
            }
            
            return history;
            
        } catch (Exception e) {
            System.debug('Error fetching approval history: ' + e.getMessage());
            return new List<ApprovalHistoryItem>();
        }
    }
    
    /**
     * Approve a template
     * Called by approver when reviewing and approving
     */
    @AuraEnabled
    public static ApprovalActionResult approveTemplate(
        Id approvalId,
        String comments
    ) {
        try {
            if (approvalId == null) {
                return new ApprovalActionResult(false, 'Approval ID required');
            }
            
            // Fetch approval
            String query = 'SELECT Id, Status__c, Approver__c, InterviewTemplate__c FROM TemplateApproval__c WHERE Id = :approvalId LIMIT 1';
            List<SObject> approvals = Database.query(query);
            
            if (approvals.isEmpty()) {
                return new ApprovalActionResult(false, 'Approval not found');
            }
            
            SObject approval = approvals[0];
            Id approverId = (Id)approval.get('Approver__c');
            String status = (String)approval.get('Status__c');
            
            // Validate current user is approver
            if (approverId != UserInfo.getUserId()) {
                return new ApprovalActionResult(false, 'Only the approver can approve this request');
            }
            
            // Validate status is pending
            if (status != 'Pending') {
                return new ApprovalActionResult(false, 'This approval has already been ' + status.toLowerCase());
            }
            
            // Update approval
            approval.put('Status__c', 'Approved');
            approval.put('Decision_Date__c', DateTime.now());
            approval.put('Comments__c', comments);
            approval.put('Resolved_Date__c', DateTime.now());
            
            Database.SaveResult sr = Database.update(approval, false);
            
            if (!sr.isSuccess()) {
                String errorMsg = 'Failed to approve';
                System.debug(errorMsg);
                return new ApprovalActionResult(false, errorMsg);
            }
            
            Id templateId = (Id)approval.get('InterviewTemplate__c');
            ApprovalActionResult result = new ApprovalActionResult(true, 'Template approved successfully');
            result.templateId = templateId;
            result.newStatus = 'Approved';
            
            System.debug('Approval ' + approvalId + ' approved for template ' + templateId);
            
            return result;
            
        } catch (Exception e) {
            System.debug('Error approving template: ' + e.getMessage());
            return new ApprovalActionResult(false, 'Error: ' + e.getMessage());
        }
    }
    
    /**
     * Reject a template
     */
    @AuraEnabled
    public static ApprovalActionResult rejectTemplate(
        Id approvalId,
        String comments,
        String rejectionReason
    ) {
        try {
            if (approvalId == null) {
                return new ApprovalActionResult(false, 'Approval ID required');
            }
            
            // Fetch approval
            String query = 'SELECT Id, Status__c, Approver__c, InterviewTemplate__c FROM TemplateApproval__c WHERE Id = :approvalId LIMIT 1';
            List<SObject> approvals = Database.query(query);
            
            if (approvals.isEmpty()) {
                return new ApprovalActionResult(false, 'Approval not found');
            }
            
            SObject approval = approvals[0];
            Id approverId = (Id)approval.get('Approver__c');
            String status = (String)approval.get('Status__c');
            
            // Validate current user is approver
            if (approverId != UserInfo.getUserId()) {
                return new ApprovalActionResult(false, 'Only the approver can reject this request');
            }
            
            // Validate status is pending
            if (status != 'Pending') {
                return new ApprovalActionResult(false, 'This approval has already been ' + status.toLowerCase());
            }
            
            // Update approval
            approval.put('Status__c', 'Rejected');
            approval.put('Decision_Date__c', DateTime.now());
            approval.put('Comments__c', comments);
            approval.put('Rejection_Reason__c', rejectionReason);
            approval.put('Resolved_Date__c', DateTime.now());
            
            Database.SaveResult sr = Database.update(approval, false);
            
            if (!sr.isSuccess()) {
                String errorMsg = 'Failed to reject';
                System.debug(errorMsg);
                return new ApprovalActionResult(false, errorMsg);
            }
            
            Id templateId = (Id)approval.get('InterviewTemplate__c');
            ApprovalActionResult result = new ApprovalActionResult(true, 'Template rejected');
            result.templateId = templateId;
            result.newStatus = 'Rejected';
            
            System.debug('Approval ' + approvalId + ' rejected for template ' + templateId);
            
            return result;
            
        } catch (Exception e) {
            System.debug('Error rejecting template: ' + e.getMessage());
            return new ApprovalActionResult(false, 'Error: ' + e.getMessage());
        }
    }
    
    /**
     * Auto-approve template (for templates with only library questions)
     * Called internally when no bespoke questions exist
     */
    @AuraEnabled
    public static ApprovalActionResult autoApprove(
        Id templateId,
        String autoApproveReason
    ) {
        try {
            if (templateId == null) {
                return new ApprovalActionResult(false, 'Template ID required');
            }
            
            // Fetch template + program
            String templateQuery = 'SELECT Id, Program__c FROM InterviewTemplate__c WHERE Id = :templateId LIMIT 1';
            List<SObject> templates = Database.query(templateQuery);
            
            if (templates.isEmpty()) {
                return new ApprovalActionResult(false, 'Template not found');
            }
            
            SObject template = templates[0];
            Id programId = (Id)template.get('Program__c');
            
            // Create auto-approval record
            SObject approval = (SObject)Type.forName('TemplateApproval__c').newInstance();
            approval.put('InterviewTemplate__c', templateId);
            approval.put('Program__c', programId);
            approval.put('Submitted_By__c', UserInfo.getUserId());
            approval.put('Status__c', 'Auto-Approved');
            approval.put('Submitted_Date__c', DateTime.now());
            approval.put('Decision_Date__c', DateTime.now());
            approval.put('Resolved_Date__c', DateTime.now());
            approval.put('Comments__c', autoApproveReason);
            
            Database.SaveResult sr = Database.insert(approval, false);
            
            if (!sr.isSuccess()) {
                String errorMsg = 'Failed to auto-approve';
                System.debug(errorMsg);
                return new ApprovalActionResult(false, errorMsg);
            }
            
            ApprovalActionResult result = new ApprovalActionResult(true, 'Template auto-approved (no bespoke questions)');
            result.templateId = templateId;
            result.newStatus = 'Auto-Approved';
            
            System.debug('Template ' + templateId + ' auto-approved');
            
            return result;
            
        } catch (Exception e) {
            System.debug('Error auto-approving template: ' + e.getMessage());
            return new ApprovalActionResult(false, 'Error: ' + e.getMessage());
        }
    }
    
    // ========== Helper Methods ==========
    
    /**
     * Count bespoke questions in a template
     * Bespoke = no Library_Definition__c reference
     */
    private static Integer countBespokeQuestions(Id templateId) {
        try {
            // Get versions first, then count bespoke questions
            String versionQuery = 'SELECT Id FROM InterviewTemplateVersion__c WHERE InterviewTemplate__c = :templateId';
            List<SObject> versions = Database.query(versionQuery);
            Set<Id> versionIds = new Set<Id>();
            for (SObject v : versions) { versionIds.add(v.Id); }
            
            String query = 'SELECT COUNT() FROM InterviewQuestion__c WHERE InterviewTemplateVersion__c IN :versionIds AND Library_Definition__c = NULL';
            return (Integer)Database.countQuery(query);
        } catch (Exception e) {
            System.debug('Error counting bespoke questions: ' + e.getMessage());
            return 0;
        }
    }
}
