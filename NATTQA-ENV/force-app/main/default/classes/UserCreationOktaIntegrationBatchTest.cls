@isTest
public class UserCreationOktaIntegrationBatchTest {
    @isTest
    static void testBatchProcess() {
        // Step 1: Create test users
        List<User> testUsers = new List<User>();
        for (Integer i = 0; i < 10; i++) {
            testUsers.add(new User(
                FirstName = 'Test',
                LastName = 'User' + i,
                Email = 'test' + i + '@example.com',
                UCP_Region__c = 'EMEA',
                UCP_Permission_Set__c = 'UCP All',
                Username = 'test' + i + '@abexample.com',  // Corrected here
                Alias = 'newuser', 
                TimeZoneSidKey = 'America/New_York',  // Set to a valid time zone
                LocaleSidKey = 'en_US',  // Set to a valid locale
                EmailEncodingKey = 'UTF-8',  // Set to the encoding for emails
                LanguageLocaleKey = 'en_US',  // Set to the language locale
                ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1].Id
            ));
        }
        insert testUsers;
        
        Set<Id> userIds = new Set<Id>();
        for (User user : testUsers) {
            userIds.add(user.Id);
        }
        UserCreationOktaIntegrationBatch batchProcessor = new UserCreationOktaIntegrationBatch(userIds);
        
        // Step 3: Mock callouts for external systems (Okta)
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockOktaCallout());
        
        // Step 4: Execute the batch job
        Database.executeBatch(batchProcessor);
        Test.stopTest();
    }
    
    // Mock response for Okta API callouts
    class MockOktaCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"id": "oktaId123", "status": "PROVISIONED"}');
            res.setStatusCode(200);
            return res;
        }
    }
}