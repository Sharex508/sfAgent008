/********************************************************************************************************************************
 *  @author 
 *  @date   
 *  @description  Test Class for NPSResponseDataSender
 *  Modification Log:
 *  ---------------------------------------------------------------------------------------------------------------------------
 *  Developer                   Date                  Description
 *  Your Name                   Today's Date          Initial Version
 *********************************************************************************************************************************
**/
@isTest
public with sharing class NPSResponseDataSenderTest {
    
    // Define constants for test data
    private static final String TEST_ACCOUNT_NUMBER = '1234443232398';
    private static final String TEST_ACCOUNT_NAME = 'Testing Account';
    private static final String TEST_CONTACT_FIRSTNAME = 'Testing';
    private static final String TEST_CONTACT_LASTNAME = 'User_' + System.currentTimeMillis();
    private static final String TEST_CONTACT_EMAIL = 'test@123829292sfdc.com';
    private static final String TEST_TICKET_NUMBER_PREFIX = 'T-4618';
    private static final String TEST_RECORD_NPS_ID_PREFIX = 'R_2ruRV3MXLc2VN50';
    
    /**
     * @description - Setup data required for testing    
     */
    @testSetup
    static void setupData() {
        // Create a test user
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User testUser = new User(
            Username = 'testuser' + System.currentTimeMillis() + '@example.com',
            Email = 'testuser' + System.currentTimeMillis() + '@example.com',
            LastName = 'TestUser',
            Alias = 'tuser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;
        
        // Run as the test user
        System.runAs(testUser) {
            // Create Account
            Account testAccount = new Account(
                AccountNumber = TEST_ACCOUNT_NUMBER,
                Name = TEST_ACCOUNT_NAME,
                Status__c = 'Active',
                NATT_Organization__c = 'NATT',
                NATT_Region__c = 'East'
                // Add other necessary fields if required
            );
            insert testAccount;
            
            // Create Contact related to the Account
            Contact testContact = new Contact(
                FirstName = TEST_CONTACT_FIRSTNAME,
                LastName = TEST_CONTACT_LASTNAME,
                Email = TEST_CONTACT_EMAIL,
                AccountId = testAccount.Id
                // Add other necessary fields if required
            );
            insert testContact;
            
            // Create a Case related to the Account and Contact
            Case testCase = new Case(
                Subject = 'Customer Feedback Follow Up',
                Status = 'Closed',
                Origin = 'Web',
                AccountId = testAccount.Id,
                ContactId = testContact.Id,
                nps_Ticket_Number__c = TEST_TICKET_NUMBER_PREFIX + '0',
                CLF_PCI__c = 'CLF_PCI_1', // Ensure this picklist value exists
                CLF_AT__c = 'CLF_AT_1',   // Ensure this picklist value exists
                Internal_Comments__c = 'Internal comment for testing'
                // Add other necessary fields if required
            );
            insert testCase;
            
            // Optionally, create nps_Feedback__c records if required by your org
            // Insert nps_Feedback__c records as needed
        }
    }
    
    /**
     * @description - Test method to verify initiating Qualtrics Callout
     */
    @isTest
    static void testInitiateQualtricsCallout() {
        // Retrieve the test Case
        Case testCase = [SELECT Id, Status, nps_Ticket_Number__c FROM Case LIMIT 1];
        System.assertNotEquals(null, testCase, 'Test Case should not be null');
        System.assertNotEquals(null, testCase.nps_Ticket_Number__c, 'nps_Ticket_Number__c should be set');
        
        // Set up the mock response for HTTP callouts
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        // Start test context
        Test.startTest();
        
        // Call the method to initiate the Qualtrics Callout
        NPSResponseDataSender.initiateQualtricsCallout(new List<Id> { testCase.Id });
        
        // Since initiateQualtricsCallout calls a @future method, we need to stop test to execute it
        Test.stopTest();
        
        // Optionally, perform assertions or verify that the callouts were made as expected
        // For example, check debug logs or any side effects
    }
    
    /**
     * @description - Test method to verify behavior when nps_Ticket_Number__c is null
     */
    @isTest
    static void testInitiateQualtricsCalloutWithNullTicketNumber() {
        // Create a new Case with nps_Ticket_Number__c as null
        User testUser = [SELECT Id FROM User WHERE Username LIKE 'testuser%' LIMIT 1];
        System.runAs(testUser) {
            Account testAccount = [SELECT Id FROM Account WHERE Name = :TEST_ACCOUNT_NAME LIMIT 1];
            Contact testContact = [SELECT Id FROM Contact WHERE Email = :TEST_CONTACT_EMAIL LIMIT 1];
            
            Case nullTicketCase = new Case(
                Subject = 'Customer Feedback Follow Up - Null Ticket',
                Status = 'Closed',
                Origin = 'Web',
                AccountId = testAccount.Id,
                ContactId = testContact.Id,
                nps_Ticket_Number__c = null, // Intentionally set to null
                CLF_PCI__c = 'CLF_PCI_1',
                CLF_AT__c = 'CLF_AT_1',
                Internal_Comments__c = 'Internal comment for testing with null ticket number'
            );
            insert nullTicketCase;
        }
        
        // Retrieve the new Case
        Case nullTicketCase = [SELECT Id, Status, nps_Ticket_Number__c FROM Case WHERE Subject = 'Customer Feedback Follow Up - Null Ticket' LIMIT 1];
        //System.assertNull(nullTicketCase.nps_Ticket_Number__c, 'nps_Ticket_Number__c should be null');
        
        // Set up the mock response for HTTP callouts (even though it shouldn't be called)
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        // Start test context
        Test.startTest();
        
        // Call the method to initiate the Qualtrics Callout
        NPSResponseDataSender.initiateQualtricsCallout(new List<Id> { nullTicketCase.Id });
        
        // Since initiateQualtricsCallout calls a @future method, we need to stop test to execute it
        Test.stopTest();
        
        // Optionally, perform assertions to ensure no callouts were made
        // This can be done by verifying that no changes occurred or specific logs
    }
    
    /**
     * @description - Mock class to simulate HTTP responses from Qualtrics
     */
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // Create a fake response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"meta": {"requestId": "mocked-request-id","httpStatus": "200 - OK"}}');
            res.setStatusCode(200);
            return res;
        }
    }
}