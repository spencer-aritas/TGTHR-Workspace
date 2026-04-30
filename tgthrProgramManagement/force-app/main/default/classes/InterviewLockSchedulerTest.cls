@isTest
private class InterviewLockSchedulerTest {

    @isTest
    static void testExecute() {
        Test.startTest();
        new InterviewLockScheduler().execute(null);
        Test.stopTest();
        System.assert(true, 'InterviewLockScheduler.execute completed without exception');
    }

    @isTest
    static void testSchedule() {
        Test.startTest();
        String jobId = System.schedule(
            'Test Lock Interviews',
            '0 0 2 * * ?',
            new InterviewLockScheduler()
        );
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'Scheduled job should return a non-null id');
    }
}
