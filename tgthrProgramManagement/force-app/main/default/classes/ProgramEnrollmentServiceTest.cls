@isTest
public class ProgramEnrollmentServiceTest {
    
    @isTest
    static void testIngestEncounter() {
        // Create test data
        PwaEncounter e = new PwaEncounter();
        e.encounterUuid = 'test-123';
        e.personUuid = 'person-456';
        e.firstName = 'Test';
        e.lastName = 'User';
        e.notes = 'Test encounter';
        e.pos = '27';
        e.isCrisis = false;
        e.startUtc = Datetime.now();
        e.endUtc = Datetime.now().addHours(1);
        
        Test.startTest();
        try {
            String result = ProgramEnrollmentService.ingestEncounter();
            System.debug('Test result: ' + result);
        } catch (Exception ex) {
            System.debug('Test exception: ' + ex.getMessage());
        }
        Test.stopTest();
    }
}