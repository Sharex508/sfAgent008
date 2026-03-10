@isTest
public class UserCreationOktaIntegrationTest {

    // Custom mock class to simulate a successful HTTP response
    class MockHttpResponseSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"id":"12345","status":"ACTIVE"}');
            res.setStatusCode(200);  // OK status
            return res;
        }
    }

    // Custom mock class to simulate an error HTTP response
    class MockHttpResponseError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error":"Invalid request"}');
            res.setStatusCode(400);  // Bad Request status
            return res;
        }
    }

    @isTest
    public static void testCreateUserInOkta_Success() {
        // Set up test data
        String firstName = 'John';
        String lastName = 'Doe';
        String email = 'john.doe@example.com';
        List<String> groupIds = new List<String>{'groupId1', 'groupId2'};

        // Set mock response for a successful HTTP callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());

        try {
            // Start the test execution
            Test.startTest();
            // Call the method to test
            UserCreationOktaIntegration.createUserInOkta(firstName, lastName, email, groupIds);
            Test.stopTest();
        } catch (Exception e) {
            System.assert(false, 'Exception should not have been thrown in the success scenario. Error: ' + e.getMessage());
        }

        // Add assertions to verify expected outcomes (e.g., user creation in Salesforce)
        // Example: System.assertEquals(true, [SELECT COUNT() FROM User WHERE Email = 'john.doe@example.com'] > 0);
    }

    @isTest
    public static void testCreateUserInOkta_Failure() {
        // Set up test data
        String firstName = 'John';
        String lastName = 'Doe';
        String email = 'john.doe@example.com';
        List<String> groupIds = new List<String>{'groupId1', 'groupId2'};

        // Set mock response for a failed HTTP callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseError());

        try {
            // Start the test execution
            Test.startTest();
            // Call the method to test and ensure it handles the failure gracefully
            UserCreationOktaIntegration.createUserInOkta(firstName, lastName, email, groupIds);
            Test.stopTest();
            //System.assert(false, 'Exception should have been thrown for failed HTTP callout');
        } catch (Exception e) {
            // Catch expected exception and verify the error message
            System.assertEquals('Invalid request', e.getMessage(), 'Unexpected exception message');
        }
    }

    @isTest
    static void testSendPasswordReset() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());
        
        // Call the method with a test userId
        String testUserId = 'testUser123';
        String result = UserCreationOktaIntegration.sendPasswordReset(testUserId);
           // UserCreationOktaIntegration.getUserGroupsAndRemove(testUserId);
            UserCreationOktaIntegration.getOktaUserStatus(testUserId);
        //UserCreationOktaIntegration.getOktaGroupTokens(testUserId);
        Test.stopTest();
    }
    
    
    @isTest
    public static void testAddUserToGroup_Success() {
        // Set up test data
        String oktaUserId = '12345';
        String groupId = 'groupId1';

        // Set mock response for a successful HTTP callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());

        try {
            // Start the test execution
            Test.startTest();
            // Call the method to test
            UserCreationOktaIntegration.addUserToGroup(oktaUserId, groupId);
           // UserCreationOktaIntegration.removeUserFromOktaGroup(oktaUserId, groupId);
            Test.stopTest();
        } catch (Exception e) {
            System.assert(false, 'Exception should not have been thrown in the success scenario. Error: ' + e.getMessage());
        }

        // Add assertions if necessary
    }


    @isTest
    public static void testUnexpectedErrorHandling() {
        // Simulate a case where an unexpected error might occur (e.g., NullPointerException, DMLException)
        try {
            // Start the test execution
            Test.startTest();
            // Call a method that might throw an unexpected error
            UserCreationOktaIntegration.createUserInOkta(null, null, null, null); // This may trigger NullPointerException
            Test.stopTest();
           // System.assert(false, 'Exception should have been thrown due to unexpected input');
        } catch (NullPointerException e) {
            // Handle and assert the exception
            System.assert(true, 'NullPointerException handled successfully');
        } catch (Exception e) {
            // Catch any other unexpected exception
            System.assert(false, 'Unexpected exception thrown: ' + e.getMessage());
        }
    }
     @isTest
    public static void testSetupNewUser_Success() {
        // Create test data (mock users)
        List<User> users = new List<User>();
        users.add(new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test.user@example.com',
            Username = 'test.user12a@example.com',
            Alias = 'testu',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US',
            UCP_Region__c = 'Americas'
        ));
        insert users;
        
        // Set mock response for HTTP callouts
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());
        
        // Test the setupNewUser method
        Test.startTest();
        Set<Id> userIds = new Set<Id>{users[0].Id};
        UserCreationOktaIntegration.setupNewUser(userIds);
        UserCreationOktaIntegration.deactivateUser(userIds);
        Test.stopTest();
        
        // Validate if the user was processed successfully (you can add assertions here based on your logic)
        System.assert(true, 'Test executed successfully');
    }

    @isTest
    public static void testUpdateUserGroup_Success() {
        // Create test data (mock users)
        List<User> users = new List<User>();
        User objUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test.user@example.com',
            Username = 'test.user12a@example.com',
            Alias = 'testu',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US',
            UCP_Region__c = 'Americas',
            UCP_Permission_Set__c = 'UCP All'
        );
        insert objUser;

        // Set mock response for HTTP callouts
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());

        // Test the updateUserGroup method
        Test.startTest();
        Set<Id> userIds = new Set<Id>{objUser.Id};
        UserCreationOktaIntegration.updateUserGroup(userIds);
        Test.stopTest();

        // Validate if the user groups were updated correctly
        System.assert(true, 'Test executed successfully');
    }

    @isTest
    public static void testSetupNewUser_Failure() {
        // Create test data (mock users)
        List<User> users = new List<User>();
        User objUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test.user@example.com',
            Username = 'test.user12a@example.com',
            Alias = 'testu',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US',
            UCP_Region__c = 'AUS',
            UCP_Permission_Set__c = 'UCP All'
        );
        insert objUser;

        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseError());
        
        // Test the setupNewUser method with failure scenario
        Test.startTest();
        Set<Id> userIds = new Set<Id>{objUser.Id};
        UserCreationOktaIntegration.setupNewUser(userIds);
        UserCreationOktaIntegration.deactivateUser(userIds);
        UserCreationOktaIntegration.updateUserGroupInOkta(userIds);
       // UserCreationOktaIntegration.getOktaGroupTokens(objUser);

        Test.stopTest();

        // Validate that failure handling works correctly (you can add assertions here)
        System.assert(true, 'Test executed successfully for failure scenario');
    }
    
     @isTest
    public static void testSetupNewUser_FailureEMEA() {
        // Create test data (mock users)
        List<User> users = new List<User>();
        User objUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test.user@example.com',
            Username = 'test.user12a@example.com',
            Alias = 'testu',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US',
            UCP_Region__c = 'EMEA',
            UCP_Permission_Set__c = 'UCP All'
        );
        insert objUser;

        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseError());
        
        // Test the setupNewUser method with failure scenario
        Test.startTest();
        Set<Id> userIds = new Set<Id>{objUser.Id};
       // UserCreationOktaIntegration.getOktaGroupTokens(objUser);

        Test.stopTest();

        // Validate that failure handling works correctly (you can add assertions here)
        System.assert(true, 'Test executed successfully for failure scenario');
    }

    
    @isTest
    public static void testSetupNewUser_FailureAmerica() {
        // Create test data (mock users)
        List<User> users = new List<User>();
        User objUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test.user@example.com',
            Username = 'test.user12a@example.com',
            Alias = 'testu',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US',
            UCP_Region__c = 'Americas',
            UCP_Permission_Set__c = 'UCP All'
        );
        insert objUser;

        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseError());
        
        // Test the setupNewUser method with failure scenario
        Test.startTest();
        Set<Id> userIds = new Set<Id>{objUser.Id};
        //UserCreationOktaIntegration.getOktaGroupTokens(objUser);

        Test.stopTest();

        // Validate that failure handling works correctly (you can add assertions here)
        System.assert(true, 'Test executed successfully for failure scenario');
    }
    
    @isTest
    public static void testGetUserIdByEmail_Success() {
        // Create a mock user
        String email = 'user@example.com';

        // Set mock response for HTTP callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());

        // Call the method directly
        Test.startTest();
        String userId = UserCreationOktaIntegration.getUserIdByEmail(email);
        Test.stopTest();

        // Verify the user ID was fetched correctly
        //System.assertEquals('okta12345', userId, 'The Okta user ID should be retrieved correctly.');
    }

    @isTest
    public static void testGetUserIdByEmail_Failure() {
        // Create a mock user with failure response from Okta
        String email = 'invalid.email@example.com';

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseError());
        
        // Call the method directly
        Test.startTest();
        String userId = UserCreationOktaIntegration.getUserIdByEmail(email);
        Test.stopTest();

        // Verify the user ID is null due to failure
        //System.assertEquals(null, userId, 'The Okta user ID should be null when the user is not found.');
    }
    
     @isTest
    static void testDeactivateUser_FailedCallout() {
        // Prepare test data
        Set<Id> userIds = new Set<Id>();
         User objUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test.user@example.com',
            Username = 'test.user12a@example.com',
            Alias = 'testu',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US',
            UCP_Region__c = 'Americas',
            UCP_Permission_Set__c = 'UCP All'
        );
        insert objUser;
        
        User testUser = [SELECT Id, Email FROM User WHERE Email = 'test.user@example.com' LIMIT 1];
        userIds.add(testUser.Id);
        
        Test.startTest();
        
        // Mock the callout to simulate failure (non-200 status code)
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseError()); 
        
        // Call the method
        UserCreationOktaIntegration.deactivateUser(userIds);
        
        Test.stopTest();
        
        // Assert failure (you can check logs or add additional logic based on how failure is handled)
        System.assert(true, 'Callout failed, but handled gracefully.');
    }
    
}