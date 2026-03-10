@IsTest
private class OrderTriggerHandlerNattTest {
    @IsTest static void unitTest(){
        Order o = [SELECT Id,AccountId,NATT_Billing_Address_Account_Id__c,NATT_Shipping_Address_Account_Id__c FROM Order];        
        Account a = [SELECT Id FROM Account WHERE Name='Test Dealer2'];        
        o.AccountId=a.Id;
        update o;
        delete o;
    }
	@TestSetup static void setupData(){
        List<Account> aList = new List<Account>();
        alist.add(new Account(Name='Test Dealer',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()));
        aList.add(new Account(Name='Test Dealer2',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()));
        insert aList;
        
        List<NATT_Address__c> addList = new List<NATT_Address__c>();
        addList.add(new NATT_Address__c(NATT_Type__c='Billing',NATT_Account__c=aList.get(0).Id,RecordTypeId=Schema.SObjectType.NATT_Address__c.getRecordTypeInfosByDeveloperName().get('NATT_Address').getRecordTypeId()));
        addList.add(new NATT_Address__c(NATT_Type__c='Units Ship To',NATT_Account__c=aList.get(0).Id,RecordTypeId=Schema.SObjectType.NATT_Address__c.getRecordTypeInfosByDeveloperName().get('NATT_Address').getRecordTypeId()));
        insert addList;		
		
		List<Opportunity> oppList = new List<Opportunity>();
        oppList.add(new Opportunity(Name='UnitsTestOpp',CloseDate=Date.today().addDays(30),StageName='Qualification',AccountId=aList.get(0).Id,RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_Units').getRecordTypeId(),NATT_Stock__c=true,NATT_Billing_Address__c=addList.get(0).Id,NATT_Shipping_Address__c=addList.get(1).Id));        
        insert oppList;
	        
        List<Order> orderList = new List<Order>();
        orderList.add(new Order(AccountId=aList.get(0).Id,OpportunityId=oppList.get(0).Id,EffectiveDate=Date.today().addDays(3),Status='Draft',RecordTypeId=Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('NATT_Units_Order').getRecordTypeId(),NATT_Billing_Address__c=addList.get(0).Id,NATT_Shipping_Address__c=addList.get(1).Id));
        insert orderList;
    }
}