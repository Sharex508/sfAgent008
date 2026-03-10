@IsTest
private class NattDeleteAccountConTest {
	@isTest
    static void testAccountDelete(){        
        Profile p = [SELECT Id FROM Profile WHERE Name='NATT Account Super User']; 
        User u = new User(Alias = 'standt', Email='standarduser@testorg.com', 
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='testuserxyzaccountdel@testorg.com.corp.prod');
        insert u;
        
        Map<String,Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();        
        System.runAs(u){
            List<Account> aList = new List<Account>();
            aList.add(new Account(Name='Dealer',RecordTypeId=rtMap.get('Dealer').getRecordTypeId()));
            insert aList;
            
            NattDeleteAccountCon.deleteAccount(aList.get(0).Id);
        }
    }    
}