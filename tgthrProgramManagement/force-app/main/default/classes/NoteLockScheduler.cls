/**
 * Scheduled job to lock InteractionSummary records 72 hours after completion.
 * 
 * Mirrors the InterviewLockScheduler behavior for InteractionSummary (notes).
 * Implements EHR industry standard where documentation must be finalized
 * within a certain timeframe, after which it becomes locked and requires
 * supervisor override to modify.
 * 
 * Schedule: Runs nightly at 2:15 AM (15 minutes after Interview lock job)
 * 
 * Example scheduling:
 * System.schedule('Lock Notes After 72 Hours', '0 15 2 * * ?', new NoteLockScheduler());
 * 
 * @author TGTHR Development Team
 * @date 2025-12-18
 */
public class NoteLockScheduler implements Schedulable {
    
    /**
     * Execute scheduled job
     */
    public void execute(SchedulableContext ctx) {
        DocumentationDeadlineService.processNoteLocks();
    }
}
