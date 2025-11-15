/**
 * TemplateApprovalController — LWC endpoint for template approval operations
 * 
 * Delegates to TemplateApprovalService for business logic.
 * Provides @AuraEnabled methods for interviewBuilderHome LWC.
 */
public with sharing class TemplateApprovalController {
    
    @AuraEnabled
    public static TemplateApprovalService.SubmitApprovalResult submitForApproval(
        Id templateId,
        String lintReportJson,
        String manifestJson,
        String templateVersion
    ) {
        return TemplateApprovalService.submitForApproval(
            templateId,
            lintReportJson,
            manifestJson,
            templateVersion
        );
    }
    
    @AuraEnabled(cacheable=true)
    public static List<TemplateApprovalService.ApprovalSummary> getPendingApprovalsForCurrentUser() {
        return TemplateApprovalService.getPendingApprovalsForCurrentUser();
    }
    
    @AuraEnabled(cacheable=true)
    public static List<TemplateApprovalService.ApprovalHistoryItem> getApprovalHistory(Id templateId) {
        return TemplateApprovalService.getApprovalHistory(templateId);
    }
    
    @AuraEnabled
    public static TemplateApprovalService.ApprovalActionResult approveTemplate(
        Id approvalId,
        String comments
    ) {
        return TemplateApprovalService.approveTemplate(approvalId, comments);
    }
    
    @AuraEnabled
    public static TemplateApprovalService.ApprovalActionResult rejectTemplate(
        Id approvalId,
        String comments,
        String rejectionReason
    ) {
        return TemplateApprovalService.rejectTemplate(approvalId, comments, rejectionReason);
    }
    
    @AuraEnabled
    public static TemplateApprovalService.ApprovalActionResult autoApprove(
        Id templateId,
        String autoApproveReason
    ) {
        return TemplateApprovalService.autoApprove(templateId, autoApproveReason);
    }
}
