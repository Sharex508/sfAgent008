@isTest(seeAllData = true)
public class ctbrOrderInboundIntegration_Test {
    public static SBQQ__Quote__c quote;
    public static SBQQ__Quote__c quoteObj;
    public static Order order;
    public static Order orderObj;
    public static Account acc;
    public static Account accObj;
    public static OrderItem orderItem;
    public static Product2 testProduct;
    
    static void setData() {
        acc = new Account();
        acc.Name = 'Test';
        insert acc;
        
        Recordtype recType = [select id,name,SobjectType from RecordType where name = 'CTBR Units Quote'];
        
        quote = new SBQQ__Quote__c();
        quote.SBQQ__Primary__c = true;
        quote.SBQQ__Status__c = 'Approved';
        quote.NATT_Quote_Request_Date__c = date.today();
        quote.NATT_Dealer_Comments__c = 'Test';
        quote.CTBR_Quote_Delivery_Date__c = date.today().addDays(1);
        quote.CTBR_Freight_Terms__c = 'CIF';
        quote.NATT_Product_Family__c = 'Trailer';
        quote.recordtypeId = recType.Id;
  	    //quote.NATT_Shipment_Method__c = 'Best Way';
  	    //quote.SBQQ__Primary__c = true;
        quote.SBQQ__PaymentTerms__c = 'Net 31';
        quote.CTBR_Tax_Observation__c = 'tax';
        insert quote;
                
        Recordtype recTypeOd = [select id,name,SobjectType from RecordType where name = 'CTBR Units Order'];
        
        order = new Order();
        order.Sent_to_SAP__c = true;
        order.Status = 'Draft';
        order.AccountId = acc.id;
        order.EffectiveDate = date.today();
        //order.SBQQ__Quote__c = quote.id;
        order.recordtypeId = recTypeOd.Id;
        order.CTBR_TaxObservation__c = 'Test';
        order.NATT_Dealer_Comments__c = 'ok';
        order.NATT_Shipment_Method__c = 'BW1';
        order.NATT_Shipment_Terms__c = 'COL';
        insert order;
        
        order.CTBR_Sales_Order_Draft_Number__c = 12345;
        order.CTBR_Delivery_Date__c = date.today().addDays(1);
        order.NATT_Approval_Comments__c = 'Test';
        order.NATT_Ship_Date__c = date.today();
        order.NATT_Order_Status__c = 'Partially Shipped';//2/13
        update order;
        
        testProduct = new Product2();
        testProduct.Name = 'Product Test';              
        insert testProduct;
        
        orderItem = new OrderItem();
        orderItem.Quantity = 10;
        orderItem.UnitPrice = 100;
        orderItem.ListPrice = 200;
        orderItem.OrderId = order.Id;
        orderItem.Product2Id = testProduct.Id; 
        insert orderItem;
        
        order.Status = 'Activated';
        update order;
        
        system.debug('order-->'+order);
    }
        
    static testMethod void testgetOrderandQuote() {
        setData();
        Order ord =  [SELECT id,recordtype.name,Sent_to_SAP__c,SBQQ__Quote__c,Status,AccountId,EffectiveDate FROM Order where id =: order.id];
        system.debug('ord-->'+ord);
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/retrieveOrders/' + ord.Id;
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;
        try{
            ctbrOrderInboundIntegration.getOrderandQuote();
        }catch (Exception e) {
            ctbrUtility.LogException(e,'ctbrOrderInboundIntegration','getOrderandQuote');
        }
        system.assertEquals(ord.Sent_to_SAP__c, true);
        system.assertEquals(ord.Status, 'Activated');
        system.assertEquals(ord.AccountId, acc.id);
        system.assertEquals(ord.EffectiveDate,date.today());
    }
    
    static testMethod void testPut() {
        setData();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/retrieveOrders/';
        req.httpMethod = 'PUT';
        RestContext.request = req;
        RestContext.response = res;
        Order ordr = [SELECT id,CTBR_Sales_Order_Draft_Number__c,AccountId, CTBR_Delivery_Date__c, NATT_Order_Status__c,NATT_Approval_Comments__c, NATT_Ship_Date__c FROM Order where id =: order.id];
        System.debug('Order Sales Draft number is '+ordr.CTBR_Sales_Order_Draft_Number__c);
        System.debug('Order id is'+ordr.Id);
        //dharani 19/1
        Order ordrLst = [SELECT id,CTBR_Sales_Order_Draft_Number__c,AccountId, CTBR_Delivery_Date__c, NATT_Order_Status__c,NATT_Approval_Comments__c, NATT_Ship_Date__c FROM Order where id =: order.id];
        List<ctbrOrderInboundIntegration.orderWrapper> orderWrap = new List<ctbrOrderInboundIntegration.orderWrapper>();
        ctbrOrderInboundIntegration.orderWrapper oL = new ctbrOrderInboundIntegration.orderWrapper();
        oL.Status = 'Draft';
        oL.approvalComments = 'test';
        oL.deliverydate = date.today().addDays(1);
        oL.salesdraftNumber = 12345;
        oL.OrderExternalId = ordrLst.id; 
        oL.nattStatus = 'Partially Shipped';//2/13
        orderWrap.add(oL);
        try {
            ctbrOrderInboundIntegration.updateOrder(orderWrap);
        } catch (Exception e) {
            ctbrUtility.LogException(e,'ctbrOrderInboundIntegration','updateOrder');
        }
    }
}