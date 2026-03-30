/**
 * Scheduled job to lock interviews 72 hours after completion.
 * 
 * Implements EHR industry standard where documentation must be finalized
 * within a certain timeframe, after which it becomes locked and requires
 * supervisor override to modify.
 * 
 * Schedule: Runs nightly at 2 AM
 * 
 * Example scheduling:
 * System.schedule('Lock Interviews After 72 Hours', '0 0 2 * * ?', new InterviewLockScheduler());
 * 
 * @author TGTHR Development Team
 * @date 2025-11-21
 */
public class InterviewLockScheduler implements Schedulable {
    
    /**
     * Execute scheduled job
     */
    public void execute(SchedulableContext ctx) {
        DocumentationDeadlineService.processInterviewLocks();
    }
}
