@IsTest
private class UserTriggerHandlerNattTest {
    @isTest static void handlePermissions(){
		Profile profileId = [SELECT Id FROM Profile WHERE Name = 'NATT Dealer Master User' LIMIT 1];
        
     	User usr = new User(LastName = 'User',
                           FirstName='Test',
                           Alias = 'txyz123',
                           Email = 'test@testxyz123.com',
                           Username = 'kn@testxyz123.com',
                           ProfileId = profileId.id,
                           TimeZoneSidKey = 'America/New_York',
                           LanguageLocaleKey = 'en_US',
                           EmailEncodingKey = 'UTF-8',
                           LocaleSidKey = 'en_US',
                           NATT_Dealer__c=true,
                           CTM_Dealer_Region_2__c=true,
                           CTBR_Dealer__c=true
                           );        
        insert usr;
        
        usr.NATT_Associate__c=true;
        usr.NATT_Dealer__c=false;
        usr.CTM_Dealer_Region_1__c=true;
        usr.CTBR_Internal__c=true;
        usr.NATT_Customer__c=true;
        usr.NATT_Dealer_Principal__c=true;
        usr.NATT_Internal__c=true;
        usr.CTM_Internal__c=true;
        usr.CTM_Dealer_Region_3__c=true;
        
        update usr;
    }
}