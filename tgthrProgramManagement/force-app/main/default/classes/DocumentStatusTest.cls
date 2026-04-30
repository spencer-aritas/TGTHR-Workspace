@isTest
public class DocumentStatusTest {

    @isTest
    static void testAllConstants() {
        // Reference every constant to cover the static initializers
        System.assertEquals('Published', DocumentStatus.NOTE_PENDING);
        System.assertEquals('Recalled', DocumentStatus.NOTE_RECALLED);
        System.assertEquals('Completed', DocumentStatus.NOTE_COMPLETED);
        System.assertEquals('In Progress', DocumentStatus.INTERVIEW_IN_PROGRESS);
        System.assertEquals('Submitted', DocumentStatus.INTERVIEW_SUBMITTED);
        System.assertEquals('Recalled', DocumentStatus.INTERVIEW_RECALLED);
        System.assertEquals('Signed', DocumentStatus.INTERVIEW_SIGNED);
        System.assertEquals('Voided', DocumentStatus.INTERVIEW_VOIDED);
        System.assertEquals('Amended', DocumentStatus.INTERVIEW_AMENDED);
    }
}
