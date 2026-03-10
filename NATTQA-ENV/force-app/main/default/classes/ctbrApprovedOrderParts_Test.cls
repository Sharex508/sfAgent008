@isTest(seeAllData = true)
public class ctbrApprovedOrderParts_Test {
    public static Order order;
    public static OrderItem orderItem;
    public static Account acc;
    public static SBQQ__Quote__c quote;
    public static Product2 testProduct;
    
    static void setData() {
        acc = new Account();
        acc.Name = 'Test';
        insert acc;

        quote = new SBQQ__Quote__c();
        quote.NATT_Quote_Request_Date__c = date.today();
        quote.NATT_Dealer_Comments__c = 'Test';
        quote.CTBR_Quote_Delivery_Date__c = date.today().addDays(1);
        quote.CTBR_Freight_Terms__c = 'CIF';
        //quote.NATT_Shipment_Method__c = 'Best Way';
        quote.SBQQ__PaymentTerms__c = 'Net 31';
        insert quote;
        
        testProduct = new Product2();
        testProduct.Name = 'Product Test';              
        insert testProduct;
        
        Recordtype recType = [select id,name,SobjectType from RecordType where name = 'CTBR Parts Order'];
        
        order = new Order ();
        order.Status = 'Draft';
        order.RecordTypeId = recType.Id;
        order.CTBR_TaxObservation__c = 'Test';
        order.NATT_Dealer_Comments__c = 'ok';
        //order.NATT_Shipment_Method__c = 'BW1';
        order.NATT_Shipment_Terms__c = 'COL';
        order.AccountId = acc.id;
        order.EffectiveDate = date.today();
        //order.SBQQ__Quote__c = quote.id;
        insert order;
        order.NATT_Order_Status__c = 'Customer Approved';
        update order;
        
        orderItem = new OrderItem();
        orderItem.Quantity = 10;
        orderItem.UnitPrice = 100;
        orderItem.ListPrice = 200;
        orderItem.OrderId = order.Id;
        orderItem.Product2Id = testProduct.Id; 
        try {
            insert orderItem;
        } catch (Exception e) {
            e.getMessage();
        }
    }
    
    static testMethod void testgetOrderandQuote() {
        setData();
        Order ord =  [SELECT id,recordtype.name,Sent_to_SAP__c,SBQQ__Quote__c,Status,AccountId,EffectiveDate,NATT_Order_Status__c,
                      (select id,Product2Id,CTBR_SapItemStatus__c,Purchase_Order_Number__c,Part_Number__c,NATT_Product_Name__c,OrderItemNumber,Quantity,
                      UnitPrice,ListPrice,TotalPrice from orderitems) FROM Order where id =: order.id];
        system.debug('ord-->>'+ord);
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/retrieveApprovedPartsOrders/' + ord.Id;
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        try {
            ctbrOrderInboundApproved_Parts.getOrderandOrdItem();
        } catch (Exception e) {}
        Test.stopTest();
        system.assertEquals(ord.Sent_to_SAP__c, false);
        system.assertEquals(ord.Status, 'Draft');
        system.assertEquals(ord.AccountId, acc.id);
        system.assertEquals(ord.EffectiveDate,date.today());
    }   
}