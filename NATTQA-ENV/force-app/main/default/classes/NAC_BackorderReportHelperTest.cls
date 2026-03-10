@isTest
public with sharing class NAC_BackorderReportHelperTest {
    
     @isTest(SeeAllData=true)
    private static void getOrderList_Test(){
        Profile testProfile = [SELECT Id FROM Profile WHERE Name = 'NAC Customer Community Profile' LIMIT 1];
        
        Account a = new Account(
            Name='Test',
            NATT_Organization__c = 'NATT',
            NATT_Region__c = 'East'
           // RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()
        );
        insert a;
        Contact c = new Contact(
            AccountId=a.Id,
            FirstName='Test',
            LastName='User',
            NATT_Key_Business_Role__c='Principal',
            RecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NAOCAP_End_Customer').getRecordTypeId()
        );
        insert c;
        User testUser = new User(
            Username = 'testUser@testclass.com', 
            LastName = 'testing', 
            Email = 'test@test.test', 
            Alias = 'tuser', 
            TimeZoneSidKey = 'America/New_York', 
            LocaleSidKey = 'en_US', 
            EmailEncodingKey = 'ISO-8859-1', 
            LanguageLocaleKey = 'en_US',
            ProfileId = testProfile.Id,
            ContactId = c.Id
        );
        insert testUser;
        
        String recordType = Schema.SObjectType.Order.getRecordTypeInfosByName().get('NATT Parts Order').getRecordTypeId();
        Order testOrder = new Order(
           // RecordTypeId = Schema.SObjectType.Order.getRecordTypeInfosByName().get('NATT Parts Order').getRecordTypeId(),
            AccountId = a.Id,
            Status = 'Draft',
            EffectiveDate = System.today(),
            Type = 'Stock',
            OrderedDate = (DateTime) System.today(),
            NATT_Purchase_Order__c= '1234',
            NATT_Shipment_Terms__c = 'PPD',
            NATT_JDE_Sales_Order_Number__c = '555'          
        );
        
        insert testOrder;
        
        Product2 testProduct = new Product2(
            Name = 'Product Test'        
        );
        
        insert testProduct;
        
        Product2 testProduct2 = new Product2(
            Name = 'Product Test2'        
        );
        
        insert testProduct2;
        
        Product2 testProduct3 = new Product2(
            Name = 'Product Test3'        
        );
        
        insert testProduct3;
        
        OrderItem testOrderItem = new OrderItem(
            OrderId = testOrder.Id,
            LineNumber = 10,
            Product2Id = testProduct.Id,
            Quantity = 4,
            UnitPrice = 2,
            ListPrice = 123,
            NATT_Backordered_Quantity__c = 5
            
        );
        
        insert testOrderItem; 
        
        OrderItem testOrderItem02 = new OrderItem(
            OrderId = testOrder.Id,
            LineNumber = 11,
            Product2Id = testProduct2.Id,
            Quantity = 6,
            UnitPrice = 3,
            ListPrice = 150,
            NATT_Backordered_Quantity__c = 5
            
        );
        insert testOrderItem02; 
        
        OrderItem testOrderItem03 = new OrderItem(
            OrderId = testOrder.Id,
            LineNumber = 12,
            Product2Id = testProduct3.Id,
            Quantity = 1,
            UnitPrice = 1,
            ListPrice = 100,
            NATT_Backordered_Quantity__c = 5
        );
        insert testOrderItem03;
        //old method start
        Boolean orderItemCheck = false;
        Test.startTest();
        //   List <OrderItem> testList = NATT_BackorderReportHelper.getOrderList();
        List<Map<String, Object>> testList = NAC_BackorderReportHelper.getOrderList();
        
        Test.stopTest();
        if (testList != null){
            orderItemCheck = true;
        }
        System.assertEquals(true, orderItemCheck, ' We expect the getOrderList method to return a list of Order Items');
    }
    
    @isTest(SeeAllData=true)
    private static void getTopOrderedItems_Test(){
        Profile testProfile = [SELECT Id FROM Profile WHERE Name = 'NAC Customer Community Profile' LIMIT 1];
        
        Account a = new Account(
            Name='Test123',
            NATT_Organization__c = 'NATT',
            NATT_Region__c = 'East'
           // RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()
        );
        insert a;
        Contact c = new Contact(
            AccountId=a.Id,
            FirstName='Test',
            LastName='User',
            NATT_Key_Business_Role__c='Principal',
            RecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NAOCAP_End_Customer').getRecordTypeId()
        );
        insert c;
        User testUser = new User(
            Username = 'testUser@testclass.com', 
            LastName = 'testing', 
            Email = 'test@test.test', 
            Alias = 'tuser', 
            TimeZoneSidKey = 'America/New_York', 
            LocaleSidKey = 'en_US', 
            EmailEncodingKey = 'ISO-8859-1', 
            LanguageLocaleKey = 'en_US',
            ProfileId = testProfile.Id,
            ContactId = c.Id
        );
        insert testUser;
        
        String recordType = Schema.SObjectType.Order.getRecordTypeInfosByName().get('NATT Parts Order').getRecordTypeId();
        Order testOrder = new Order(
          //  RecordTypeId = Schema.SObjectType.Order.getRecordTypeInfosByName().get('NATT Parts Order').getRecordTypeId(),
            AccountId = a.Id,
            Status = 'Draft',
            EffectiveDate = System.today(),
            Type = 'Stock',
            OrderedDate = (DateTime) System.today(),
            NATT_Purchase_Order__c= '1234',
            NATT_Shipment_Terms__c = 'PPD',
            NATT_JDE_Sales_Order_Number__c = '555'          
        );
        
        insert testOrder;
        
        Product2 testProduct = new Product2(
            Name = 'Product Test'        
        );
        
        insert testProduct;
        
        Product2 testProduct2 = new Product2(
            Name = 'Product Test2'        
        );
        
        insert testProduct2;
        
        Product2 testProduct3 = new Product2(
            Name = 'Product Test3'        
        );
        
        insert testProduct3;
        
        OrderItem testOrderItem = new OrderItem(
            OrderId = testOrder.Id,
            LineNumber = 10,
            Product2Id = testProduct.Id,
            Quantity = 4,
            UnitPrice = 2,
            ListPrice = 123,
            NATT_Backordered_Quantity__c = 5
            
        );
        
        insert testOrderItem; 
        
        OrderItem testOrderItem02 = new OrderItem(
            OrderId = testOrder.Id,
            LineNumber = 11,
            Product2Id = testProduct2.Id,
            Quantity = 6,
            UnitPrice = 3,
            ListPrice = 150,
            NATT_Backordered_Quantity__c = 5
            
        );
        insert testOrderItem02; 
        
        OrderItem testOrderItem03 = new OrderItem(
            OrderId = testOrder.Id,
            LineNumber = 12,
            Product2Id = testProduct3.Id,
            Quantity = 1,
            UnitPrice = 1,
            ListPrice = 100,
            NATT_Backordered_Quantity__c = 5
        );
        insert testOrderItem03;
        // List <OrderItem> testList = new List <OrderItem>();
        List<NAC_BackorderReportHelper.TopBackorderWrapper> testList = new List<NAC_BackorderReportHelper.TopBackorderWrapper>();
        Boolean orderItemCheck = false;
        // Order testOrder = [SELECT Id FROM Order];
        // User testUser = [SELECT Username FROM User WHERE Username = 'testUser@testclass.com'];
        String idValue = null;
        Product2 testProduct4 = new Product2(
            Name = 'Product Test4'        
        );
        insert testProduct4;
        OrderItem testOrderItem04 = new OrderItem(
            OrderId = testOrder.Id,
            LineNumber = 13,
            Product2Id = testProduct4.Id,
            Quantity = 1000,
            UnitPrice = 9,
            ListPrice = 190,
            NATT_Backordered_Quantity__c = 1000
            
        );
        insert testOrderItem04;
        
        Test.startTest();
        testList = NAC_BackorderReportHelper.getTopOrderedItems(testUser.id);
        Test.stopTest();
        
        for(NAC_BackorderReportHelper.TopBackorderWrapper item : testList) {
            idValue = item.Id;
            break;
        }
        
        System.assertEquals(testOrderItem04.Id, idValue, 'We expect the first OrderItem to be the one with the largest Quantity value.');
    }
    
    /**
* This will test the getResults method. 
* This test will check what happens when a user searches for all the fields at once, as well as indivudally check each field to make sure it pulls up appropriate records.
*/
    @isTest(SeeAllData=true)
    private static void getResults_Test(){
        //old method start
        List<Map<String, Object>> returnItemList = new List<Map<String, Object>> ();
        List<OrderItem> orderItemList = new List<OrderItem>();
        
        List<Map<String, Object>> returnItemListPoNumber = new List<Map<String, Object>> ();
                List<OrderItem> orderItemList1 = new List<OrderItem>();

       List<Map<String, Object>> returnItemListOrderNumber = new List<Map<String, Object>> ();
                List<OrderItem> orderItemList2 = new List<OrderItem>();

        List<Map<String, Object>> returnItemPartNumber = new List<Map<String, Object>>();
                List<OrderItem> orderItemList3 = new List<OrderItem>();

        List<Map<String, Object>> returnItemListFromDate = new List<Map<String, Object>> ();
                List<OrderItem> orderItemList4 = new List<OrderItem>();

        List<Map<String, Object>> returnItemListToDate = new List<Map<String, Object>> ();
                List<OrderItem> orderItemList5 = new List<OrderItem>();

        Account testAccount = [SELECT ID FROM Account LIMIT 1];
        Order newOrder = new Order(
           // RecordTypeId = Schema.SObjectType.Order.getRecordTypeInfosByName().get('NATT Parts Order').getRecordTypeId(),
            AccountId = testAccount.Id,
            Status = 'Draft',
            EffectiveDate = System.today(),
            Type = 'Stock',
            OrderedDate = (DateTime) System.today(),
            NATT_Purchase_Order__c= '56789999999bkordTest',
            NATT_Shipment_Terms__c = 'PPD',
            NATT_JDE_Sales_Order_Number__c = '999'
        );
        insert newOrder;
        Product2 testProduct5 = new Product2(
            Name = 'Result Product Test01',
            NATT_P_N__c = '3450297784'        
        );
        insert testProduct5;
        OrderItem newItem = new OrderItem(        	
            OrderId = newOrder.Id,
            LineNumber = 10,
            Product2Id = testProduct5.Id,
            Quantity = 4,
            UnitPrice = 2,
            ListPrice = 123,
            NATT_Backordered_Quantity__c = 5
            
        );
        insert newItem;
        List<OrderItem> itemList = [SELECT Id,Order_Number__c, Order_Date__c, Part_Number__c, Purchase_Order_Number__c FROM OrderItem WHERE OrderId =: newOrder.Id];
        Test.startTest();
        String orderNumber = '999';
        String poNumber = '56789999999bkordTest';
        Date fromDate =  System.today() - 1;
        Date toDate = System.today() + 1;
        String partNumber = '3450297784';
        returnItemList = NAC_BackorderReportHelper.getResults(orderNumber, poNumber, partNumber, fromDate, toDate);
        SYstem.debug('Return Item List Value: ' + returnItemList);
        
        returnItemListOrderNumber = NAC_BackorderReportHelper.getResults(orderNumber, null, null, null, null);
        returnItemListPoNumber = NAC_BackorderReportHelper.getResults(null, poNumber, null, null, null);
        returnItemPartNumber = NAC_BackorderReportHelper.getResults(null, null, partNumber, null, null);
        returnItemListFromDate = NAC_BackorderReportHelper.getResults(null, null, null, (fromDate - 1), null);
        returnItemListToDate = NAC_BackorderReportHelper.getResults(null, null, null, null, toDate);
        
        Test.stopTest();
        
        String returnIdCheckNew = null;
        String returnIdCheckOrderNumber = null;
        String returnIdCheckPoNumber = null;
        String returnIdCheckFromDate = null;
        String returnIdCheckToDate = null;
        
        /*   for(OrderItem item: returnItemList){
SYstem.debug('Item Value: ' + item);
returnIdCheckNew = item.Id;
}*/
        for (Map<String, Object> item : returnItemList) {
            OrderItem orderItem = new OrderItem();
            orderItem.Id = (Id)item.get('Id');
            orderItemList.add(orderItem);
        }
        
        for (OrderItem item : orderItemList) {
            System.debug('Item Value: ' + item);
            returnIdCheckNew = item.Id;
        }
       /* for(OrderItem item: returnItemListOrderNumber){
            returnIdCheckOrderNumber = item.Id;
        }*/
        for (Map<String, Object> item : returnItemListOrderNumber) {
            OrderItem orderItem = new OrderItem();
            orderItem.Id = (Id)item.get('Id');
            orderItemList2.add(orderItem);
        }
        
        for (OrderItem item : orderItemList2) {
            System.debug('Item Value: ' + item);
            returnIdCheckOrderNumber = item.Id;
        }
        
       /* for(OrderItem item: returnItemListPoNumber){
            returnIdCheckPoNumber = item.Id;
        }*/
        for (Map<String, Object> item : returnItemListPoNumber) {
            OrderItem orderItem = new OrderItem();
            orderItem.Id = (Id)item.get('Id');
            orderItemList1.add(orderItem);
        }
        
        for (OrderItem item : orderItemList1) {
            System.debug('Item Value: ' + item);
            returnIdCheckPoNumber = item.Id;
        }
         for (Map<String, Object> item : returnItemListOrderNumber) {
            OrderItem orderItem = new OrderItem();
            orderItem.Id = (Id)item.get('Id');
            orderItemList2.add(orderItem);
        }
        
        for (OrderItem item : orderItemList2) {
            System.debug('Item Value: ' + item);
            returnIdCheckOrderNumber = item.Id;
        }
        
       /* for(OrderItem item: returnItemListFromDate){
            returnIdCheckFromDate = item.Id;
        }*/
        for (Map<String, Object> item : returnItemListFromDate) {
            OrderItem orderItem = new OrderItem();
            orderItem.Id = (Id)item.get('Id');
            orderItemList4.add(orderItem);
        }
        
        for (OrderItem item : orderItemList4) {
            System.debug('Item Value: ' + item);
            returnIdCheckFromDate = item.Id;
        }
        
      /*  for(OrderItem item: returnItemListToDate){
            returnIdCheckToDate = item.Id;
        }*/
        for (Map<String, Object> item : returnItemListToDate) {
            OrderItem orderItem = new OrderItem();
            orderItem.Id = (Id)item.get('Id');
            orderItemList5.add(orderItem);
        }
        
        for (OrderItem item : orderItemList5) {
            System.debug('Item Value: ' + item);
            returnIdCheckToDate = item.Id;
        }
        

    }

}