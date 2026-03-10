@IsTest
private class NattAddressSelectionConTest {
    @isTest static void myUnitTest(){
        List<Account> aList = [SELECT Id FROM Account];
        NattAddressSelectionCon.Wrapper w = NattAddressSelectionCon.getAddressList(aList.get(0).Id,aList.get(1).Id,'Billing');
        NattAddressSelectionCon.Wrapper unitsW = NattAddressSelectionCon.getAddressList(aList.get(0).Id,aList.get(1).Id,'Units Ship To');
        
        Opportunity opp = [SELECT Id FROM Opportunity];
        String quoteId = NattQuoteCon.createQuote(opp.Id,true);
        
        NattAddressSelectionCon.getQuoteInfo(quoteId);
        List<Map<String,String>> billingList  = w.dealerAddressList;
        List<Map<String,String>> unitsList  = unitsW.endCustomerAddressList;
        String billingId,unitsId;
        
        billingId=billingList.get(0).get('value');        
        unitsId=unitsList.get(0).get('value');
        
        NattAddressSelectionCon.updateQuote(quoteId,opp.Id,billingId,unitsId);
    }
    
    @isTest static void myUnitTestFromOrder(){
        List<Account> aList = [SELECT Id FROM Account];
        NattAddressSelectionCon.Wrapper w = NattAddressSelectionCon.getAddressList(aList.get(0).Id,aList.get(1).Id,'Billing');
        NattAddressSelectionCon.Wrapper unitsW = NattAddressSelectionCon.getAddressList(aList.get(0).Id,aList.get(1).Id,'Units Ship To');
        Order o = [SELECT Id FROM Order];
        o = NattAddressSelectionCon.getOrderInfo(o.Id);
        List<Map<String,String>> billingList  = w.dealerAddressList;
        List<Map<String,String>> unitsList  = unitsW.endCustomerAddressList;
        String billingId,unitsId;
        
        billingId=billingList.get(0).get('value');        
        unitsId=unitsList.get(0).get('value');
        
        NattAddressSelectionCon.updateOrder(o.Id,billingId,unitsId);
    }
    
    @TestSetup static void setupData(){        
        List<Pricebook2> pbList = new List<Pricebook2>();
        pbList.add(new Pricebook2(Name='NATT Units Price Book',IsActive=true));
        pbList.add(new Pricebook2(Name='NATT Parts Price Book',IsActive=true));
        insert pbList;
        
        List<Account> aList = new List<Account>();
        aList.add(new Account(Name='Test Dealer',NATT_Organization__c = 'NATT',NATT_Region__c = 'East',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()));
        aList.add(new Account(Name='Test Dealer2',NATT_Organization__c = 'NATT',NATT_Region__c = 'East',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()));
        insert aList;
        
        Account a = aList.get(0);
        Account b = aList.get(1);
        
        List<NATT_Address__c> addList = new List<NATT_Address__c>();
        addList.add(new NATT_Address__c(NATT_Account__c=a.Id,NATT_Type__c='Mailing',NATT_Street__c='111 Test Street',NATT_City__c='Dalton',NATT_State_Province__c='GA',NATT_Zip_Postal_Code__c='30720',NATT_Country__c='US'));
        addList.add(new NATT_Address__c(NATT_Account__c=a.Id,NATT_Type__c='Billing',NATT_Street__c='111 Test Street',NATT_City__c='Dalton',NATT_State_Province__c='GA',NATT_Zip_Postal_Code__c='30720',NATT_Country__c='US'));
        addList.add(new NATT_Address__c(NATT_Account__c=a.Id,NATT_Type__c='Units Ship To',NATT_Street__c='111 Test Street',NATT_City__c='Dalton',NATT_State_Province__c='GA',NATT_Zip_Postal_Code__c='30720',NATT_Country__c='US'));
        addList.add(new NATT_Address__c(NATT_Account__c=b.Id,NATT_Type__c='Mailing',NATT_Street__c='111 Test Street',NATT_City__c='Dalton',NATT_State_Province__c='GA',NATT_Zip_Postal_Code__c='30720',NATT_Country__c='US'));
        addList.add(new NATT_Address__c(NATT_Account__c=b.Id,NATT_Type__c='Billing',NATT_Street__c='111 Test Street',NATT_City__c='Dalton',NATT_State_Province__c='GA',NATT_Zip_Postal_Code__c='30720',NATT_Country__c='US'));
        addList.add(new NATT_Address__c(NATT_Account__c=b.Id,NATT_Type__c='Units Ship To',NATT_Street__c='111 Test Street',NATT_City__c='Dalton',NATT_State_Province__c='GA',NATT_Zip_Postal_Code__c='30720',NATT_Country__c='US'));
        insert addList;
        
        Opportunity opp = new Opportunity(Name='TestUnitsOpp',CloseDate=Date.today().addDays(30),StageName='Qualification',AccountId=a.Id,RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_Units').getRecordTypeId(),NATT_Stock__c=true);
        insert opp;
        
        Order o = new Order(OpportunityId=opp.Id,AccountId=a.Id,NATT_End_Customer__c=b.Id,RecordTypeId=Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('NATT_Units_Order').getRecordTypeId(),EffectiveDate=Date.today(),Status='Draft');
        insert o;
    }
}