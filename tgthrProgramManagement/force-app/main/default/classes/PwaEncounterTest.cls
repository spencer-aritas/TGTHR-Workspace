@isTest
public class PwaEncounterTest {

    @isTest
    static void testInstantiation() {
        PwaEncounter enc = new PwaEncounter();
        enc.encounterUuid = 'uuid-123';
        enc.personUuid = 'person-456';
        enc.firstName = 'Jane';
        enc.lastName = 'Doe';
        enc.startUtc = DateTime.now();
        enc.endUtc = DateTime.now().addHours(1);
        enc.pos = '11 - Office';
        enc.isCrisis = false;
        enc.notes = 'Test notes';
        enc.location = 'Denver';
        enc.services = 'Counseling';
        enc.deviceId = 'device-789';
        System.assertEquals('Jane', enc.firstName);
        System.assertEquals('uuid-123', enc.encounterUuid);
        System.assertEquals(false, enc.isCrisis);
    }

    @isTest
    static void testNullFields() {
        PwaEncounter enc = new PwaEncounter();
        System.assertEquals(null, enc.encounterUuid);
        System.assertEquals(null, enc.firstName);
        System.assertEquals(null, enc.isCrisis);
    }
}
