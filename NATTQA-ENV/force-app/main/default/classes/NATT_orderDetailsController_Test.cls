@isTest
private class NATT_orderDetailsController_Test {
    public Class OrderItemWrapper {
        @AuraEnabled public String trackingNumber {get;set;}
    }
    public Class OrderWrapper {
        @AuraEnabled public List < OrderItemWrapper > orderItems{get;set;}
    }
    
    @testSetup
    private static void testSetup(){
        
        List<Account> aList = new List<Account>();
        alist.add(new Account(Name='Test Dealer',NATT_Organization__c = 'NATT',NATT_Region__c = 'East',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()));
        aList.add(new Account(Name='Test Dealer2',NATT_Organization__c = 'NATT',NATT_Region__c = 'East',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()));
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
        
        
        Product2 testProduct = new Product2(
        	Name = 'Product Test'        
        );
        
        insert testProduct;
        List<OrderItem> orderItemList = new List<OrderItem>();
        for (Integer i=0; i<200; i++){
            OrderItem testOrderItem = new OrderItem(
                OrderId = orderList[0].Id,
                LineNumber = i+1,
                Product2Id = testProduct.Id,
                Quantity = 4,
                UnitPrice = i+1,
                ListPrice = i+1
            );
            orderItemList.add(testOrderItem);
        }
        insert orderItemList;
        // OrderItem testOrderItem = new OrderItem(
        // 	OrderId = orderList[0].Id,
        //     LineNumber = 10,
        //     Product2Id = testProduct.Id,
        //     Quantity = 4,
        //     UnitPrice = 2,
        //     ListPrice = 123
        // );
        
        // insert testOrderItem; 
        
        Shipment testShip = new Shipment(
        	ShipToName = 'test',
        	NATT_PackingSlipNumber__c = 345678,
            TrackingNumber = '12345',
            NATT_Order__c = orderList[0].Id,
            ExpectedDeliveryDate = System.today() + 1,
            NATT_ShippingCompanyName__c = 'ABF FREIGHT',
            RecordTypeId=Schema.SObjectType.Shipment.getRecordTypeInfosByDeveloperName().get('NATT_Parts_Shipment').getRecordTypeId()
        );
        
        insert testShip;
        
        List<ShipmentItem> itemList = new List <ShipmentItem>();
        for (Integer i=0; i<200; i++){
            ShipmentItem testShipItem = new ShipmentItem(
        	// NATT_OrderProduct__c = testOrderItem.Id,
            NATT_OrderProduct__c = orderItemList[i].Id,
            ShipmentId = testShip.Id,
            Product2Id = testProduct.Id,
            Quantity = 23,
            NATT_Amount__c = 12,
            NATT_InvoiceNumber__c = i+1,
            NATT_DateShipped__c = System.today()
            
        );
        itemList.add(testShipItem);
        }
        // ShipmentItem testShipItem = new ShipmentItem(
        // 	NATT_OrderProduct__c = testOrderItem.Id,
        //     ShipmentId = testShip.Id,
        //     Product2Id = testProduct.Id,
        //     Quantity = 23,
        //     NATT_Amount__c = 12,
        //     NATT_InvoiceNumber__c = 978865,
        //     NATT_DateShipped__c = System.today()
            
        // );
        
        // insert testShipItem;
        insert itemList;
    }
    
    @isTest
    private static void fetchOrderlines_test(){
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        Test.startTest();
         NATT_orderDetailsController.fetchOrderlines(testOrder.Id);            
        Test.stopTest(); 
    }   
    
    @isTest
    private static void fetchShipmentItems_test(){
        OrderItem testOrderItem = [SELECT Id FROM OrderItem LIMIT 1];
        Test.startTest();
          NATT_orderDetailsController.fetchShipmentItems(testOrderItem.Id);        
        Test.stopTest(); 
    } 

    @isTest
    private static void fetchInvoiceInformation_test(){
        Shipment testShipment = [SELECT Id FROM Shipment WHERE ShipToName = 'test' LIMIT 1];
        NATT_orderDetailsController.OrderWrapper testWrapper = new NATT_orderDetailsController.OrderWrapper();
        Test.startTest();
        testWrapper = NATT_orderDetailsController.fetchInvoiceInformation(testShipment.Id);
        Test.stopTest();
        for(NATT_orderDetailsController.OrderItemWrapper itemWrapper : testWrapper.orderItems ){
            System.assertEquals('12345', itemWrapper.trackingNumber, 'We expect the fetchOrderInformation method to grab Shipment Item infromation.');
        }
    }
    
   

}