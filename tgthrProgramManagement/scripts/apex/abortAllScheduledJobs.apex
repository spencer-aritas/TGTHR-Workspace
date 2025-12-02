// Abort all scheduled jobs to allow deployment
// Run this before doing a full org deploy

List<CronTrigger> jobs = [
    SELECT Id, CronJobDetail.Name, State, NextFireTime
    FROM CronTrigger
    ORDER BY CronJobDetail.Name
];

System.debug('Found ' + jobs.size() + ' scheduled jobs');

for (CronTrigger job : jobs) {
    System.debug('Aborting: ' + job.CronJobDetail.Name + ' (ID: ' + job.Id + ')');
    try {
        System.abortJob(job.Id);
    } catch (Exception e) {
        System.debug('Failed to abort ' + job.Id + ': ' + e.getMessage());
    }
}

System.debug('✅ All scheduled jobs aborted');
System.debug('You can now deploy safely');
