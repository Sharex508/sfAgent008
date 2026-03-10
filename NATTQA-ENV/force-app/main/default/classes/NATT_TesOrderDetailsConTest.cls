@isTest
private class NATT_TesOrderDetailsConTest {
    public Class OrderItemWrapper {
        @AuraEnabled public String trackingNumber {get;set;}
    }
    public Class OrderWrapper {
        @AuraEnabled public List < OrderItemWrapper > orderItems{get;set;}
    }
    @testSetup
    private static void testSetup(){
        
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
        
        Shipment testShip = new Shipment(
        	ShipToName = 'test',
        	NATT_PackingSlipNumber__c = 345678,
            TrackingNumber = '12345',
            NATT_Order__c = orderList[0].Id,
            ExpectedDeliveryDate = System.today() + 1

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
        insert itemList;
    }
    
    @isTest
    private static void getOrder_test(){
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        Order returnOrder = null;
        Test.startTest();
        returnOrder = NATT_TesOrderDetailsCon.grabOrder(testOrder.Id);            
        Test.stopTest(); 
        Boolean isPopulated = false;
        if(returnOrder != null){
            isPopulated = true;
        }
        System.assertEquals(true, isPopulated, 'We expect the grabOrder method to return an order.');
    }   
    
    @isTest
    private static void getOrderItems_test(){
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        List <OrderItem> orderItemList = new List <OrderItem>();
        Test.startTest();
        orderItemList = NATT_TesOrderDetailsCon.grabOrderItems(testOrder.Id);        
        Test.stopTest(); 
        Boolean isPopulated = false;
        if(!orderItemList.isEmpty()){
            isPopulated = true;
        }
        System.assertEquals(true, isPopulated, 'We expect the getShipment method to return a list of order items.');
    } 

    // @isTest
    // private static void getShipments_test(){
    //     Order testOrder = [SELECT Id FROM Order LIMIT 1];
    //     List <Shipment> returnShipments = new List <Shipment>();
    //     Test.startTest();
    //     returnShipments = NATT_TesOrderDetailsCon.getShipment(testOrder.Id);        
    //     Test.stopTest(); 
    //     Boolean isPopulated = false;
    //     if(!returnShipments.isEmpty()){
    //         isPopulated = true;
    //     }
    //     System.assertEquals(true, isPopulated, 'We expect the getShipment method to return a list of shipments.');

    // } 

    // @isTest
    // private static void getShipmentInformation_test(){
    //     Shipment testShipment = [SELECT Id FROM Shipment WHERE ShipToName = 'test' LIMIT 1];
    //     Shipment returnShipment = null;
    //     NATT_orderDetailsController.OrderWrapper testWrapper = new NATT_orderDetailsController.OrderWrapper();
    //     Test.startTest();
    //     returnShipment = NATT_TesOrderDetailsCon.getShipmentInvoice(testShipment.Id);
    //     Test.stopTest();
    //     Boolean isPopulated = false;
    //     if(returnShipment != null){
    //         isPopulated = true;
    //     }
    //     System.assertEquals(true, isPopulated, 'We expect the getShipment method to return a shipment');


    // }

    @isTest
    private static void fetchOrderlines_test(){
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        Test.startTest();
          NATT_TesOrderDetailsCon.fetchOrderlines(testOrder.Id);            
        Test.stopTest(); 
    }   

}