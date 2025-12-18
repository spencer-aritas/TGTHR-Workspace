/**
 * Test class for NoteLockScheduler
 * 
 * @author TGTHR Development Team
 * @date 2025-12-18
 */
@isTest
public class NoteLockSchedulerTest {
    
    @isTest
    static void testSchedulerExecution() {
        Test.startTest();
        
        // Schedule the job
        String jobId = System.schedule(
            'Test Lock Notes', 
            '0 0 2 * * ?', 
            new NoteLockScheduler()
        );
        
        Test.stopTest();
        
        // Verify job was scheduled
        List<CronTrigger> scheduledJobs = [
            SELECT Id, CronExpression, State 
            FROM CronTrigger 
            WHERE Id = :jobId
        ];
        
        System.assertEquals(1, scheduledJobs.size(), 'Job should be scheduled');
    }
    
    @isTest
    static void testExecuteWithNoRecords() {
        Test.startTest();
        
        NoteLockScheduler scheduler = new NoteLockScheduler();
        scheduler.execute(null);
        
        Test.stopTest();
        
        // No assertions needed - just verify no exceptions
    }
}
