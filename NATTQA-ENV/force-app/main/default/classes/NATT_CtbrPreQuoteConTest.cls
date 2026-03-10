@IsTest
private class NATT_CtbrPreQuoteConTest {
    @IsTest
    static void testGetData(){
        List<Order> oList = NATT_CtbrPreQuoteCon.getOrders('Awaiting Customer Approval');

        List<OrderItem> oiLIst = NATT_CtbrPreQuoteCon.getOutOfStock();

        List<String> oosList = new List<String>();
        for(OrderItem oi : oiList){
            System.debug('qAvail : '+oi.CTBR_QuantityAvailable__c);
            if(oi.CTBR_QuantityAvailable__c==0){
                oosList.add(oi.Id);
            }
        }
        System.debug('oosList: '+oosList);
        NATT_CtbrPreQuoteCon.createOrderFromOutOfStock(oosList);

        NATT_CtbrPreQuoteCon.approveOrder(oList.get(0).Id);
    }

    @TestSetup
    static void makeData(){
        List<Account> aList = new List<Account>();
        alist.add(new Account(Name='Test CTBR Dealer',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('CTBR_Dealer').getRecordTypeId()));        
        insert aList;
        
        List<NATT_Address__c> addList = new List<NATT_Address__c>();
        addList.add(new NATT_Address__c(NATT_Type__c='Billing',NATT_Account__c=aList.get(0).Id,RecordTypeId=Schema.SObjectType.NATT_Address__c.getRecordTypeInfosByDeveloperName().get('NATT_Address').getRecordTypeId()));
        addList.add(new NATT_Address__c(NATT_Type__c='Units Ship To',NATT_Account__c=aList.get(0).Id,RecordTypeId=Schema.SObjectType.NATT_Address__c.getRecordTypeInfosByDeveloperName().get('NATT_Address').getRecordTypeId()));
        insert addList;	
        	        
        List<Order> orderList = new List<Order>();
        orderList.add(new Order(AccountId=aList.get(0).Id,EffectiveDate=Date.today().addDays(3),Status='Draft',
            RecordTypeId=Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('CTBR_Parts_Order').getRecordTypeId(),
            NATT_Billing_Address__c=addList.get(0).Id,NATT_Shipping_Address__c=addList.get(1).Id,NATT_Order_Status__c='Awaiting Customer Approval'));
        insert orderList;
        
        
        Product2 testProduct = new Product2(Name = 'Product Test');
        
        insert testProduct;
        List<OrderItem> orderItemList = new List<OrderItem>();
        
        orderItemList.add(new OrderItem(
            OrderId = orderList[0].Id,
            Product2Id = testProduct.Id,
            Quantity = 4,
            UnitPrice = 1,
            ListPrice = 1,
            CTBR_QuantityAvailable__c=4
        ));

        orderItemList.add(new OrderItem(
            OrderId = orderList[0].Id,
            Product2Id = testProduct.Id,
            Quantity = 4,
            UnitPrice = 1,
            ListPrice = 1,
            CTBR_QuantityAvailable__c=0,
            CTBR_OutOfStockDuringApproval__c=true
        ));            
        
        insert orderItemList;        
    }
}