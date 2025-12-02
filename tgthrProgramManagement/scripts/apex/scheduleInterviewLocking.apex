// Schedule the Interview Lock Scheduler to run nightly at 2 AM
// Execute via: sf apex run --file scripts/apex/scheduleInterviewLocking.apex

// First, abort any existing scheduled jobs with this name
List<CronTrigger> existingJobs = [
    SELECT Id, CronJobDetail.Name
    FROM CronTrigger
    WHERE CronJobDetail.Name LIKE '%Lock Interviews%'
];

for (CronTrigger job : existingJobs) {
    System.debug('Aborting existing job: ' + job.CronJobDetail.Name);
    System.abortJob(job.Id);
}

// Schedule new job - runs daily at 2:00 AM
// Cron expression: Seconds Minutes Hours Day Month DayOfWeek Year
// '0 0 2 * * ?' = At 2:00 AM every day
String jobName = 'Lock Interviews After 72 Hours';
String cronExp = '0 0 2 * * ?';

String jobId = System.schedule(jobName, cronExp, new InterviewLockScheduler());

System.debug('✅ Scheduled job: ' + jobName);
System.debug('   Job ID: ' + jobId);
System.debug('   Schedule: Daily at 2:00 AM');
System.debug('   Cron: ' + cronExp);

// Query to verify
CronTrigger ct = [
    SELECT Id, CronJobDetail.Name, NextFireTime, State
    FROM CronTrigger
    WHERE Id = :jobId
];

System.debug('   Next run: ' + ct.NextFireTime);
System.debug('   State: ' + ct.State);
