@isTest
public class ServiceAgreementTriggerHelperTest {
    
    @isTest
    static void testShareServiceAgreement() {
        Account acc1 = new account();
        Account acc2 = new account();
        Id customerAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('CONTAINER Authorized Service Provider').getRecordTypeId();
        Id NAcustomerAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('CONTAINER Customer').getRecordTypeId();
        Contact cnt = new contact();
        User communityUser = new user();
        User thisUser = new User(Id = UserInfo.getUserId());
        id UserRoleid = [SELECT Id FROM UserRole WHERE Name = 'NA Units Manager' LIMIT 1 ].Id;
        thisUser.UserRoleId = UserRoleid;
        System.runAs(thisUser) {
            update thisUser;
            acc1 = new Account(
                Name = 'Authorized Service Provider 7', 
                RecordTypeId = customerAccountRecordTypeId
                
            );
            insert acc1;
            
            
            // Create Contacts
            Contact contact1 = new Contact(
                FirstName = 'Primary', 
                LastName = 'Contact', 
                AccountId = acc1.Id,
                CONTAINER_Is_Primary_Contact__c = true
            );
            insert contact1;
            Profile profile = [SELECT Id FROM Profile WHERE Name='UCP Profile' LIMIT 1];
            
            communityUser = new User(Alias='UCPTest', Email='buyer@example.com', LastName='Buyer',
                                     TimeZoneSidKey='GMT', LocaleSidKey='en_US', Username= 'UCPTestUser321'+'@example.com',
                                     EmailEncodingKey='UTF-8', ProfileId=profile.Id, LanguageLocaleKey='en_US',
                                     ContactId=contact1.Id);
            insert communityUser;
        }
        
        // Create CONTAINER_Service_Agreement__c records
        CONTAINER_Service_Agreement__c serviceAgreement = new CONTAINER_Service_Agreement__c(
            Account__c = acc1.Id
        );
        insert serviceAgreement;
        List<CONTAINER_Service_Agreement__c> SAList = new List<CONTAINER_Service_Agreement__c>();
        SAList.add(serviceAgreement);
        System.runAs(thisUser) {
            acc2 = new Account(
                Name = 'Authorized Service Provider 7', 
                RecordTypeId = customerAccountRecordTypeId,
                Authorized_Service_Provider__c = acc1.id
            );
            insert acc2;
        }
        ServiceAgreementTriggerHelper.ShareServiceAgriment(SAList);
        System.runAs(thisUser) {
        acc2.Authorized_Service_Provider__c=null;
        update acc2;
        acc2.Authorized_Service_Provider__c = acc1.id;
        update acc2;
        }
    }
   
}