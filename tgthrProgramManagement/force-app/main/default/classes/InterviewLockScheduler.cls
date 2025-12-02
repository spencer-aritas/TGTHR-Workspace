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
        // Query interviews that are completed but not locked and past 72 hours
        DateTime lockThreshold = DateTime.now().addHours(-72);
        
        String query = 
            'SELECT Id, Completed_On__c ' +
            'FROM Interview__c ' +
            'WHERE Is_Locked__c = false ' +
            'AND Completed_On__c != null ' +
            'AND Completed_On__c <= :lockThreshold ' +
            'LIMIT 200'; // Process in batches for governor limits
        
        List<SObject> interviewsToLock = Database.query(query);
        
        System.debug('InterviewLockScheduler: Found ' + interviewsToLock.size() + ' interviews to lock');
        
        if (interviewsToLock.isEmpty()) {
            return;
        }
        
        // Lock each interview
        Integer lockedCount = 0;
        Integer failedCount = 0;
        
        for (SObject interview : interviewsToLock) {
            try {
                Boolean locked = InterviewCompletionService.lockInterview((Id)interview.get('Id'));
                if (locked) {
                    lockedCount++;
                } else {
                    failedCount++;
                }
            } catch (Exception e) {
                System.debug('Failed to lock interview ' + interview.get('Id') + ': ' + e.getMessage());
                failedCount++;
            }
        }
        
        System.debug('InterviewLockScheduler: Locked ' + lockedCount + ' interviews, ' + failedCount + ' failures');
        
        // If there are more to process, schedule another run immediately
        if (interviewsToLock.size() >= 200) {
            System.debug('More interviews to process, scheduling immediate re-run');
            // Schedule to run again in 5 minutes
            System.schedule('Lock Interviews (Batch Continuation)', '0 ' + (DateTime.now().addMinutes(5).minute()) + ' * * * ?', new InterviewLockScheduler());
        }
    }
}
