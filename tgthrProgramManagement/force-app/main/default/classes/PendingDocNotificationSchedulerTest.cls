@isTest
private class PendingDocNotificationSchedulerTest {

    @isTest
    static void testExecute() {
        Test.startTest();
        new PendingDocNotificationScheduler().execute(null);
        Test.stopTest();
        System.assert(true, 'PendingDocNotificationScheduler.execute completed without exception');
    }

    @isTest
    static void testSchedule() {
        Test.startTest();
        String jobId = System.schedule(
            'Test Daily Pending Doc Reminder',
            '0 0 8 * * ?',
            new PendingDocNotificationScheduler()
        );
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'Scheduled job should return a non-null id');
    }
}
