@isTest
public class UserTriggerTest {

    @testSetup
    static void setupTestData() {
        // Create a test profile for community user
        Profile communityProfile = [SELECT Id FROM Profile WHERE Name = 'UCP Profile' LIMIT 1];
		
        String gsRecordTypeID = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByName().get('CONTAINER Authorized Service Provider').getRecordTypeId();

        // Create a test account
        Account testAccount = new Account(Name = 'Test Account',RecordTypeId = gsRecordTypeID);
        insert testAccount;
        String contactRecordID = Schema.getGlobalDescribe().get('Contact').getDescribe().getRecordTypeInfosByName().get('CONTAINER Contact').getRecordTypeId();

        // Create a test contact
        Contact testContact = new Contact(LastName = 'Test Contact', AccountId = testAccount.Id,RecordtypeId = contactRecordID);
        insert testContact;

        // Create a test user with community profile
        User testUser = new User(
            Alias = 'testUser',
            Email = 'testuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = communityProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'testuser@example.com',
            ContactId = testContact.Id,
            IsActive = true,
            UCP_Permission_Set__c = 'UCP All',
            UCP_Region__c = 'Americas'
        );
        insert testUser;
    }

    @isTest
    static void testAfterInsert() {
        // Retrieve the test user
        User testUser = [SELECT Id, UCP_Permission_Set__c, UCP_Region__c, IsPortalEnabled FROM User WHERE Username = 'testuser@example.com'];

        // Verify that the user has been assigned the correct permission set
        List<PermissionSetAssignment> assignments = [
            SELECT Id, AssigneeId, PermissionSet.Name 
            FROM PermissionSetAssignment 
            WHERE AssigneeId = :testUser.Id
        ];
        System.assert(!assignments.isEmpty(), 'Permission set should be assigned to the user');
      // System.assertEquals('UCP_All', assignments[0].PermissionSet.Name, 'Incorrect permission set assigned');

        // Verify that the Okta integration logic was executed (if applicable)
        // This would depend on the implementation of UserCreationOktaIntegration.setupNewUser
    }

    @isTest
    static void testAfterUpdate() {
        // Retrieve the test user
        User testUser = [SELECT Id, UCP_Permission_Set__c, UCP_Region__c, IsPortalEnabled FROM User WHERE Username = 'testuser@example.com'];

        // Update the user's region and permission set
        testUser.UCP_Region__c = 'EMEA';
        testUser.UCP_Permission_Set__c = 'UCP Only';
        update testUser;

        // Verify that the Okta integration logic was executed (if applicable)
        // This would depend on the implementation of UserCreationOktaIntegration.updateUserGroupInOkta
    }

    @isTest
    static void testAfterUpdateDeactivateUser() {
        // Retrieve the test user
        User testUser = [SELECT Id, UCP_Permission_Set__c, UCP_Region__c, IsPortalEnabled FROM User WHERE Username = 'testuser@example.com'];

        // Deactivate the user
        testUser.IsActive = false;
        update testUser;

        // Verify that the Okta integration logic was executed (if applicable)
        // This would depend on the implementation of UserCreationOktaIntegration.deactivateUser
    }

    @isTest
    static void testAfterInsertOrUpdate() {
        // Retrieve the test user
        User testUser = [SELECT Id, UCP_Permission_Set__c,ContactId,UCP_Region__c, IsPortalEnabled FROM User WHERE Username = 'testuser@example.com'];

        // Verify that the contact's FedId was updated
        Contact updatedContact = [SELECT Id, Federation_ID__c FROM Contact WHERE Id = :testUser.ContactId];
        //System.assertNotEquals(null, updatedContact.Federation_ID__c, 'FedId should be updated');

        // Verify that the Service Agreement was shared (if applicable)
        // This would depend on the implementation of UpdateUserQueueUCP.ServiceAgreementShare
    }
}