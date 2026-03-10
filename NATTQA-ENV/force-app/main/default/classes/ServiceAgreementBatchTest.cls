@isTest
public class ServiceAgreementBatchTest {

    @testSetup
    static void setupTestData() {
        Id customerAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('CONTAINER Authorized Service Provider').getRecordTypeId();
        // Create a test Account with that RecordType
        Account testAccount = new Account(
            Name = 'Test Account',
            RecordTypeId = customerAccountRecordTypeId
        );
        insert testAccount;

        // Create Service Agreement records linked to the test account
        List<CONTAINER_Service_Agreement__c> serviceAgreements = new List<CONTAINER_Service_Agreement__c>();
        for (Integer i = 0; i < 10; i++) {
            CONTAINER_Service_Agreement__c sa = new CONTAINER_Service_Agreement__c(
                Account__c = testAccount.Id
            );
            serviceAgreements.add(sa);
        }
        insert serviceAgreements;
    }

    @isTest
    static void testBatchExecution() {
        List<CONTAINER_Service_Agreement__Share> initialShares = [SELECT Id FROM CONTAINER_Service_Agreement__Share];

        // Run the batch
        Test.startTest();
        ServiceAgreementBatch batch = new ServiceAgreementBatch();
        Database.executeBatch(batch, 50);
        Test.stopTest();
    }
}