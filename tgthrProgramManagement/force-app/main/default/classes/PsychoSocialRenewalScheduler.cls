/**
 * PsychoSocialRenewalScheduler
 * 
 * Schedulable job that runs daily to check for 6-month Psycho-Social Intake renewals.
 * 
 * Schedule this job to run daily using:
 *   String cronExp = '0 0 8 * * ?'; // 8 AM daily
 *   System.schedule('Psycho-Social 6-Month Renewal Check', cronExp, new PsychoSocialRenewalScheduler());
 * 
 * Or schedule via Developer Console:
 *   PsychoSocialRenewalScheduler.scheduleDaily();
 * 
 * @author TGTHR Development Team
 * @date 2026-01
 */
public class PsychoSocialRenewalScheduler implements Schedulable {
    
    /**
     * Execute the scheduled job
     */
    public void execute(SchedulableContext ctx) {
        System.debug('PsychoSocialRenewalScheduler: Starting 6-month renewal check');
        
        try {
            Integer renewalsCreated = PsychoSocialRenewalService.processRenewals();
            System.debug('PsychoSocialRenewalScheduler: Completed - created ' + renewalsCreated + ' renewal interviews');
        } catch (Exception e) {
            System.debug('PsychoSocialRenewalScheduler: Error - ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
    
    /**
     * Convenience method to schedule the job to run daily at 8 AM
     * Run from Anonymous Apex: PsychoSocialRenewalScheduler.scheduleDaily();
     */
    public static String scheduleDaily() {
        // Run at 8:00 AM every day
        String cronExp = '0 0 8 * * ?';
        return System.schedule(
            'Psycho-Social 6-Month Renewal Check - Daily', 
            cronExp, 
            new PsychoSocialRenewalScheduler()
        );
    }
    
    /**
     * Convenience method to schedule for testing (runs in 1 minute)
     * Run from Anonymous Apex: PsychoSocialRenewalScheduler.scheduleTest();
     */
    public static String scheduleTest() {
        DateTime now = DateTime.now().addMinutes(1);
        String cronExp = '0 ' + now.minute() + ' ' + now.hour() + ' ' + now.day() + ' ' + now.month() + ' ? ' + now.year();
        return System.schedule(
            'Psycho-Social Renewal Test - ' + now.format(), 
            cronExp, 
            new PsychoSocialRenewalScheduler()
        );
    }
    
    /**
     * Run the renewal check immediately (for testing)
     * Run from Anonymous Apex: PsychoSocialRenewalScheduler.runNow();
     */
    public static Integer runNow() {
        return PsychoSocialRenewalService.processRenewals();
    }
    
    /**
     * Abort all scheduled jobs for this class
     * Run from Anonymous Apex: PsychoSocialRenewalScheduler.abortAllJobs();
     */
    public static void abortAllJobs() {
        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name 
            FROM CronTrigger 
            WHERE CronJobDetail.Name LIKE 'Psycho-Social%'
        ];
        
        for (CronTrigger job : jobs) {
            System.abortJob(job.Id);
            System.debug('Aborted job: ' + job.CronJobDetail.Name);
        }
    }
}
