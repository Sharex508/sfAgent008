@isTest(seeAllData = True)
public class ctbrOrderInbound_Parts_Test {
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
        //quote.SBQQ__Discount__c = 10;
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
        
        Recordtype recTypeOd = [select id,name,SobjectType from RecordType where name = 'CTBR Parts Order']; 
        
        order = new Order ();
        order.Status = 'Draft';
        order.CTBR_TaxObservation__c = 'Test';
        order.NATT_Dealer_Comments__c = 'ok';
        order.CTBR_Shipment_Method__c = 'Air';//updated to CTBR_Shipment_Method__c on 1/23.
        order.CTBR_Freight_Payment__c = 'CIF';//updated to CTBR_Freight_Payment__c on 1/24.
        //order.NATT_Shipment_Terms__c = 'COL';//commented on 1/25,as this is not needed.
        //order.CTBR_Shipment_Company__c = '60120'; //updated to CTBR_Shipment_Company__c on 1/25
        order.AccountId = acc.id;
        order.recordtypeId = recTypeOd.Id;
        order.EffectiveDate = date.today();
        insert order;

        orderItem = new OrderItem();
        orderItem.Quantity = 1;
        orderItem.UnitPrice = 100;
        orderItem.ListPrice = 200;
        orderItem.OrderId = order.Id;
        orderItem.Product2Id = testProduct.Id; 
        //try {
            insert orderItem;
        //} catch (Exception e) {
            //e.getMessage();
        //}
        Order ord =  [SELECT id,recordtype.name,NATT_Dealer_Comments__c,CTBR_Shipment_Method__c,CTBR_Shipment_Company__c,CTBR_Freight_Payment__c,
                      Sent_to_SAP__c,SBQQ__Quote__c,Status,AccountId,EffectiveDate, (select id,OrderItemNumber from orderitems) FROM Order where id =: order.id];
        system.debug('ord--DatatSet-->>'+ord);
    }
  
    static testMethod void updateOrderTest() {
        setData();
        Order orderObjt = [SELECT id,CTBR_Sales_Order_Draft_Number__c,CTBR_BillToLocation__c,CTBR_TotalICMS__c,CTBR_ShipToLocation__c, Status,CTBR_TotalICMSST__c,CTBR_TotalPayable__c,CTBR_TotalIPI__c,CTBR_FreightPrice__c,CTBR_Delivery_Date__c, CTBR_SubtotalICMS__c,NATT_Approval_Comments__c, NATT_Ship_Date__c FROM Order where id =: order.id];
        orderObjt.CTBR_Sales_Order_Draft_Number__c = 12345;
        orderObjt.NATT_Ship_Date__c = date.today().addDays(1);
        orderObjt.Status = 'Draft';
        orderObjt.CTBR_FreightPrice__c = 8908;
        orderObjt.CTBR_SubtotalICMS__c = 2345;
        orderObjt.CTBR_TotalICMS__c = 78798;
        orderObjt.CTBR_TotalICMSST__c = 878;
        orderObjt.CTBR_TotalIPI__c = 454;
        orderObjt.CTBR_TotalPayable__c = 5667;
        orderObjt.NATT_Approval_Comments__c = 'test';
        orderObjt.CTBR_Delivery_Date__c = date.today().addDays(10) ;
        //orderObjt.CTBR_BillToLocation__c 
        //orderObjt.CTBR_ShipToLocation__c
        update orderObjt;
      
    }   
    
    static testMethod void testgetOrderandOrdItem() {
        setData();
        Order ord =  [SELECT id,recordtype.name,NATT_Dealer_Comments__c,CTBR_Shipment_Method__c,CTBR_Shipment_Company__c,CTBR_Freight_Payment__c,
                      Sent_to_SAP__c,SBQQ__Quote__c,Status,AccountId,EffectiveDate, (select id,OrderItemNumber from orderitems) FROM Order where id =: order.id];
        system.debug('ord-->>'+ord);
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/retrievePartsOrders/' + ord.Id;
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        try {
            ctbrOrderInbound_Parts.getOrderandOrdItem();
        } catch (Exception e) {}
        Test.stopTest();
        system.assertEquals(ord.Sent_to_SAP__c, false);
        system.assertEquals(ord.Status, 'Draft');
        system.assertEquals(ord.AccountId, acc.id);
        system.assertEquals(ord.EffectiveDate,date.today());
        system.assertEquals(ord.NATT_Dealer_Comments__c, 'ok');
    }
    
    static testMethod void testPut() {
        setData();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/retrievePartsOrders/';
        req.httpMethod = 'PUT';
        RestContext.request = req;
        RestContext.response = res;
        Order ordr = [SELECT id,CTBR_Sales_Order_Draft_Number__c,AccountId, CTBR_Delivery_Date__c, NATT_Approval_Comments__c, NATT_Ship_Date__c FROM Order where id =: order.id];
        try {
            ctbrOrderInbound_Parts.updateOrder(null);
        } catch (Exception e) {}
        try {
            ctbrOrderInbound_Parts.getOrderandOrdItem();
        } catch (Exception e) {}
    }
    
  
    static testMethod void testputOrderWpr() {
        List<ctbrOrderInbound_Parts.putOrderWpr> orderWrap = new List<ctbrOrderInbound_Parts.putOrderWpr>();
        List<ctbrOrderInbound_Parts.putOrdItemWrapper> putorderItemWrap = new List<ctbrOrderInbound_Parts.putOrdItemWrapper>();
        List<ctbrOrderInbound_Parts.OrdItemWrapper> orderItemWrap = new List<ctbrOrderInbound_Parts.OrdItemWrapper>();
        ctbrOrderInbound_Parts.putOrdItemWrapper orderList = new ctbrOrderInbound_Parts.putOrdItemWrapper();
        orderList.sapItemStatus = 'Success';
        //orderList.id = null;
        //orderList.OrderItemExternalId = 'null';
        orderList.OrderNumber = 'null';
        orderList.SAPQuoteId = 'null';
        orderList.freightPrice = 11.0;
        orderList.subtotalICMS = 11.0;
        orderList.totalICMS = 11.0;
        orderList.totalIPI = 11.0;
        orderList.totalICMSST = 11.0;
        orderList.totalPayable = 11.0;
        //orderList.fixedPayment = 'null';
        //orderList.taxation = 'null';
        //orderList.globalpriceLstcode = 'null';
        //orderList.hasGlobalPriceLst = 'null';
        //orderList.paymentconditionCode = 'null';
        orderList.quantityAvailable = 1;
        orderList.quantity = 1;
        putorderItemWrap.add(orderList);

        ctbrOrderInbound_Parts.putOrderWpr cL = new ctbrOrderInbound_Parts.putOrderWpr();
        cL.salesordNumber = 'order';
        cL.salesordDraftNumber = 11;
        cL.billToLocation = 'bill';
        cL.shipToLocation = 'ship';
        cL.freightPrice = 556;
        cL.subtotalICMS = 7878;
        cL.totalICMS = 778;
        cL.totalICMSST = 678;
        cL.totalIPI = 890;
        cL.totalPayable = 6778;
        cL.approvalComments = 'Test';
        cL.deliverydate = date.today().addDays(10);
        cL.OrderStatus = 'Draft';
        cL.nattStatus = 'Complete';
        cl.orderItemLst = putorderItemWrap;
        orderWrap.add(cL);        
        ctbrOrderInbound_Parts.putOrdItemWrapper c = new ctbrOrderInbound_Parts.putOrdItemWrapper();    
        //c.orderItem = orderItemWrap;
        //c.productName = '';
        //c.quantity = 1;
        c.freightPrice = 789;
        c.subtotalICMS = 768;
        c.totalICMS = 778;
        c.totalICMSST = 780;
        c.totalIPI = 676;
        c.totalPayable = 8900;
        c.fixedPayment = 13;
        c.taxation = 87;
        c.globalpriceLstcode = 76;
        c.hasGlobalPriceLst = false;
        c.paymentconditionCode = 93;
        putorderItemWrap.add(c);        
        ctbrOrderInbound_Parts.OrdItemWrapper co = new ctbrOrderInbound_Parts.OrdItemWrapper();
        co.unitPrice = 566;
        co.quantity = 1;
        co.listPrice = 7800;
        //co.purchaseNumber = 'PO-23234';
        orderItemWrap.add(co);
        ctbrOrderInbound_Parts.updateOrder(orderWrap);
        
    }

}