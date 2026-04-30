public with sharing class BillingClearinghouseDispatchJob implements Queueable, Database.AllowsCallouts {
    private final String filterJson;
    private final String approvalReference;

    public BillingClearinghouseDispatchJob(String filterJson, String approvalReference) {
        this.filterJson = filterJson;
        this.approvalReference = approvalReference;
    }

    public void execute(QueueableContext context) {
        BillingClearinghouseService.dispatchNow(filterJson, approvalReference);
    }
}
