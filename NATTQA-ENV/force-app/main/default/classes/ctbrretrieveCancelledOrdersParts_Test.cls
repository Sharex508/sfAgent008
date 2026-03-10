@isTest(seeAllData = true)
public class ctbrretrieveCancelledOrdersParts_Test {
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
                
        Recordtype recType = [select id,name,SobjectType from RecordType where name = 'CTBR Parts Order'];
        
        order = new Order ();
        order.Status = 'Draft';
        order.NATT_Order_Status__c = 'Awaiting Customer Approval';//2/13
        order.CTBR_TaxObservation__c = 'Test';
        order.NATT_Dealer_Comments__c = 'ok';
        //order.NATT_Shipment_Method__c = 'BW1';
        order.NATT_Shipment_Terms__c = 'COL';
        order.AccountId = acc.id;
        order.EffectiveDate = date.today();
        order.RecordTypeId = recType.Id;
        //order.SBQQ__Quote__c = quote.id;
        insert order;
		
        Recordtype recTypePrd = [select id,name,SobjectType from RecordType where name = 'CTBR Product'];
        
        testProduct = new Product2();
        testProduct.Name = 'Product Test'; 
        testProduct.RecordTypeId = recTypePrd.Id;
        insert testProduct;
        
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
        
        order.NATT_Order_Status__c = 'Cancelled'; //2/13
        update order;
    }
    
    static testmethod void quoteData() {
        setData();
        try{
            ctbrretrieveCancelledOrders_Parts.getOrders();
        }catch (Exception ex) {
            System.assertEquals('expected text', ex.getMessage());
        }        
    } 
}