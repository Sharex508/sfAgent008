@isTest
public class ucp_serviceAgreementTest {
    
    @testSetup
    static void setupTestData() {
        UserRole userRole = [SELECT Id FROM UserRole WHERE DeveloperName = 'Container' LIMIT 1];
        
        User adminUser = new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1].Id,
            UserRoleId = userRole.Id,
            LastName = 'Admin',
            Alias = 'admin1',
            Email = 'adminabsy@test.com',
            Username = 'adminabsy@test.com',
            CommunityNickname = 'adminabsy',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/New_York',
            IsActive = true
        );
        insert adminUser;
        
        System.runAs(adminUser) {
            Account authorizedServiceProviderAccount = new Account(
                Name = 'Test CONTAINER Authorized Service Provider',
                RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName()
                .get('CONTAINER Authorized Service Provider')
                .getRecordTypeId()
            );
            insert authorizedServiceProviderAccount;
            
            Account customerAccount = new Account(
                Name = 'Test Account',
                Authorized_Service_Provider__c = authorizedServiceProviderAccount.Id,
                NATT_Organization__c = 'NATT',
                NATT_Region__c = 'East',
                RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName()
                .get('CONTAINER Customer')
                .getRecordTypeId(),
                OwnerId = adminUser.Id
            );
            insert customerAccount;
            
            Contact primaryContact = new Contact(
                LastName = 'Contact Last Name',
                AccountId = customerAccount.Id,
                CONTAINER_Is_Primary_Contact__c = true,
                Contact_Type__c = 'Service Contact',
                Email = 'test@xyz.com'
            );
            insert primaryContact;
            
            Contact objContact = new Contact(LastName = 'Contact Service', AccountId = authorizedServiceProviderAccount.id,CONTAINER_Is_Primary_Contact__c = true,Contact_Type__c = 'Service Contact',Email = 'test@xyz.com');
            insert objContact;
            
            User user = new User();
            user.ProfileID = [Select Id From Profile Where Name='UCP Profile'].id;
            user.EmailEncodingKey = 'ISO-8859-1';
            user.LanguageLocaleKey = 'en_US';
            user.TimeZoneSidKey = 'America/New_York';
            user.LocaleSidKey = 'en_US';
            user.FirstName = 'first';
            user.LastName = 'last';
            user.Username = 'test@uniquedomain.com';
            user.CommunityNickname = 'testUser123';
            user.Alias = 't1';
            user.Email = 'no@email.com';
            user.IsActive = true;
            user.Container_Service_Agreement__c = true;
            user.ContactId = primaryContact.Id;
            insert user;
            
            User aspUser = new User();
            aspUser.ProfileID = [Select Id From Profile Where Name='UCP Profile'].id;
            aspUser.EmailEncodingKey = 'ISO-8859-1';
            aspUser.LanguageLocaleKey = 'en_US';
            aspUser.TimeZoneSidKey = 'America/New_York';
            aspUser.LocaleSidKey = 'en_US';
            aspUser.FirstName = 'first';
            aspUser.LastName = 'last';
            aspUser.Username = 'test@uniquedomainsss.com';
            aspUser.CommunityNickname = 'testDomain';
            aspUser.Alias = 't1';
            aspUser.Email = 'no@email.com';
            aspUser.IsActive = true;
            aspUser.ContactId = objContact.Id;
            
            insert aspUser;
        }
    }
    
    @isTest
    static void testVerifyUserDetails() {
        // Run method as test user
        Test.startTest();
        
        // Fetch the test user details
        Contact objContact = [SELECT Id,Name FROM Contact LIMIT 1];
        User testUser = [SELECT Id, ContactId FROM User WHERE ContactId =: objContact.Id LIMIT 1];
        
        System.runAs(testUser) {
            // Call the method
            Boolean result = ucp_serviceAgreement.verifyUserDetails();
            
            // Verify the result
            System.assertEquals(TRUE, result, 'The method should return false for a valid user');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testServiceAccountDetail() {
        // Run method as test user
        Test.startTest();
        
        // Fetch the test user details
        Contact objContact = [SELECT Id,Name FROM Contact WHERE Name = 'Contact Service' LIMIT 1 ];
        User testUser = [SELECT Id, ContactId FROM User WHERE ContactId =: objContact.Id LIMIT 1];
        
        System.runAs(testUser) {
            // Call the method
            Boolean result = ucp_serviceAgreement.verifyUserDetails();
            
            // Verify the result
            System.assertEquals(FALSE, result, 'The method should return false for a valid user');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testGetUserServiceAccount() {
        // Run method as test user
        Test.startTest();
        
        // Fetch the test user details
        Contact objContact = [SELECT Id,Name FROM Contact LIMIT 1];
        User testUser = [SELECT Id, ContactId FROM User WHERE ContactId =: objContact.Id LIMIT 1];
        System.runAs(testUser) {
            // Call the method
            List<CONTAINER_Service_Agreement__c>list_serviceAgreement = ucp_serviceAgreement.getServiceAgreementRecord();
            
            // Verify the result
            //  System.assertEquals(null, serviceProvider, 'The service account should be null if the user does not have an associated account');
            
        }
        
        Test.stopTest();
    }
}