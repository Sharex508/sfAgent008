@IsTest
public with sharing class UCP_WhoswhoControllerTest {
    
    @TestSetup
    static void makeData() {
        UserRole userrole = [Select Id, DeveloperName From UserRole Where DeveloperName = 'Container' Limit 1];
        
        User adminUser = [Select Id, UserRoleId From User Where Profile.Name='System Administrator' AND IsActive = true Limit 1];
        
        adminUser.UserRoleId = userRole.Id;
        update adminUser;
        
        System.runAs(adminUser){
            
            Account authorizedServiceProviderAccount = new Account(
                Name = 'Test CONTAINER Authorized Service Provider',
                RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('CONTAINER Authorized Service Provider').getRecordTypeId()
            );
            insert authorizedServiceProviderAccount;
            
            Account a = new Account(name = 'Test Account',Authorized_Service_Provider__c = authorizedServiceProviderAccount.Id ,NATT_Organization__c = 'NATT',NATT_Region__c = 'East',RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('CONTAINER Customer').getRecordTypeId());
            insert a;
            
            Contact c = new Contact(LastName = 'Contact Last Name', AccountId = a.id,CONTAINER_Is_Primary_Contact__c = true,Contact_Type__c = 'Service Contact',Email = 'test@xyz.com');
            insert c;
            
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
            user.ContactId = c.Id;
            user.NATT_Whos_Who__c = true;
            
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
            aspUser.NATT_Whos_Who__c = true;
            
            insert aspUser;
            
            
        }
        
    }
    
    @IsTest
    static void getWhosWhoArticleTest(){
        
        Knowledge__kav knowObj1 = new Knowledge__kav(
            Title = 'Article Test 1',
            UrlName = 'article-test-1',
            NATT_Whos_who__c = false
        );
        Insert knowObj1;
        
        Knowledge__kav knowObj2 = new Knowledge__kav(
            Title = 'Who is who article',
            UrlName = 'who-is-who',
            NATT_Whos_who__c = true
        );
        Insert knowObj2;
        
        Knowledge__kav know = [SELECT Id, KnowledgeArticleId FROM Knowledge__kav WHERE Title = 'Who is who article' LIMIT 1];
        KbManagement.PublishingService.publishArticle(know.KnowledgeArticleId, true);
        
        Knowledge__kav know2 = [SELECT Id, KnowledgeArticleId FROM Knowledge__kav WHERE Title = 'Article Test 1' LIMIT 1];
        KbManagement.PublishingService.publishArticle(know2.KnowledgeArticleId, true);
        
        Test.startTest();
        
        // Fetch the test user details
        Contact objContact = [SELECT Id,Name FROM Contact LIMIT 1];
        User testUser = [SELECT Id, ContactId FROM User WHERE ContactId =: objContact.Id LIMIT 1];
        System.runAs(testUser) {
            
            Map<String, Object> mpReturn = UCP_WhoswhoController.getWhosWhoArticle();
            List<Knowledge__kav> ltKnowledge = (List<Knowledge__kav>) mpReturn.get('data');
        }
        Test.stopTest();
        
    }
    
    @IsTest
    static void getWhosWhoArticleFailTest() {
        Test.startTest();
        
        User adminUser = [Select Id, UserRoleId From User Where Profile.Name='System Administrator' AND IsActive = true Limit 1];
        
        Contact objContact = [SELECT Id, Name FROM Contact LIMIT 1];
        User testUser = [SELECT Id, ContactId FROM User WHERE ContactId =: objContact.Id LIMIT 1];        
        System.runAs(adminUser){
            
            
            testUser.NATT_Whos_Who__c = false;
            Update testUser;
        }
        // Fetch the test user details
        
        
        System.runAs(testUser) {
            // Mock a scenario that throws an exception (e.g., null value for a required field)
            try {
                Map<String, Object> response = UCP_WhosWhoController.getWhosWhoArticle();
                //System.assert(false, 'Exception was expected but not thrown.');
            } catch (Exception e) {
                // Assert the exception is caught and handled
                System.assertEquals(false, e != null, 'Exception should be handled gracefully.');
            }
        }
        Test.stopTest();
    }
    
}