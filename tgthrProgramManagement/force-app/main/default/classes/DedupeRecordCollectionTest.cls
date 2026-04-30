@isTest
public class DedupeRecordCollectionTest {

    @isTest
    static void testDedupeByName() {
        Account a1 = new Account(Name = 'DedupAlpha');
        Account a2 = new Account(Name = 'DedupAlpha');
        Account a3 = new Account(Name = 'DedupBeta');
        insert new List<Account>{ a1, a2, a3 };

        DedupeRecordCollection.FlowRequest req = new DedupeRecordCollection.FlowRequest();
        req.inputRecordCollection = new List<SObject>{ a1, a2, a3 };
        req.fieldToDedupeOn = 'Name';

        Test.startTest();
        List<DedupeRecordCollection.FlowResponse> results = DedupeRecordCollection.dedupe(
            new List<DedupeRecordCollection.FlowRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(2, results[0].outputRecordCollection.size());
    }

    @isTest
    static void testDedupeInvalidField() {
        Account a1 = new Account(Name = 'DedupTest');
        insert a1;

        DedupeRecordCollection.FlowRequest req = new DedupeRecordCollection.FlowRequest();
        req.inputRecordCollection = new List<SObject>{ a1 };
        req.fieldToDedupeOn = 'NonExistentField__c';

        Test.startTest();
        List<DedupeRecordCollection.FlowResponse> results = DedupeRecordCollection.dedupe(
            new List<DedupeRecordCollection.FlowRequest>{ req }
        );
        Test.stopTest();

        // Invalid field triggers SObjectException caught in catch block → empty result
        System.assertEquals(1, results.size());
        System.assertEquals(0, results[0].outputRecordCollection.size());
    }

    @isTest
    static void testFlowResponseConstructor() {
        DedupeRecordCollection.FlowResponse resp = new DedupeRecordCollection.FlowResponse();
        System.assertNotEquals(null, resp.outputRecordCollection);
        System.assertEquals(0, resp.outputRecordCollection.size());
    }
}
