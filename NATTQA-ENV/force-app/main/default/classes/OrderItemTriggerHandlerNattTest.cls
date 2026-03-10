@IsTest    
private class OrderItemTriggerHandlerNattTest {
    @IsTest
    static void myUnitTest(){
        insert new NATT_Inventory__c(Name='1235',NATT_Extended_Warranty_Code__c='quote.Name',NATT_Serial_Number__c='1235');   
        Product2 p = [SELECT Id FROM Product2 WHERE Name='Product Test'];
        List<OrderItem> orderItemList = new List<OrderItem>();
        Order o = [SELECT Id FROM Order];
        for (Integer i=0; i<50; i++){
            OrderItem testOrderItem = new OrderItem(
                OrderId = o.Id,
                LineNumber = i+1,
                Product2Id = p.Id,
                Quantity = 4,
                UnitPrice = i+1,
                NATT_Serial_Number__c = '1235'
               
            );
            orderItemList.add(testOrderItem);
        }
        insert orderItemList;
    }

    @TestSetup
    static void makeData(){
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
        orderList.add(new Order(AccountId=aList.get(0).Id,OpportunityId=oppList.get(0).Id,EffectiveDate=Date.today().addDays(3),Status='Draft',RecordTypeId=Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('NATT_Parts_Order').getRecordTypeId(),NATT_Billing_Address__c=addList.get(0).Id,NATT_Shipping_Address__c=addList.get(1).Id));
        insert orderList;
        
        
        Product2 testProduct = new Product2(
            Name = 'Product Test',
            NATT_CoreCharge__c = TRUE        
        );
        
        insert testProduct;
        
    }
}