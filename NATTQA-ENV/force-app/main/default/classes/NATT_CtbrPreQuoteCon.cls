public without sharing class NATT_CtbrPreQuoteCon {
    
    @AuraEnabled(cacheable=true)   
    public static List<Order> getOrders(String orderStatus){
        return new List<Order>([SELECT Id,OrderNumber,NATT_Order_Status__c,CTBR_PricingValidUntil__c,
        (SELECT Id,Part_Number__c,Quantity,CTBR_TotalICMS__c,CTBR_TotalICMSST__c,
        CTBR_TotalIPI__c,CTBR_TotalPayable__c,CTBR_Taxation__c,CTBR_SubtotalICMS__c,CTBR_Available__c
         FROM OrderItems) 
        FROM Order WHERE RecordType.DeveloperName='CTBR_Parts_Order' AND NATT_Order_Status__c=:orderStatus]);
    }

    @AuraEnabled(cacheable=true)   
    public static List<OrderItem> getOutOfStock(){
        return new List<OrderItem>([SELECT Id,NATT_OrderNumberSFDC__c,Part_Number__c,Quantity,CTBR_QuantityAvailable__c
         FROM OrderItem WHERE Order.RecordType.DeveloperName='CTBR_Parts_Order' AND CTBR_OutOfStockDuringApproval__c=true]);        
    }

    @AuraEnabled(cacheable=false)
    public static Order createOrderFromOutOfStock(List<String> oiIdList){
        List<OrderItem> oiInsertList = new List<OrderItem>();        
        Order o = new Order(Status='Draft',NATT_Order_Status__c='Customer Approved',EffectiveDate=Date.today());
        for(List<OrderItem> oiList : [SELECT Id,Order.AccountId,Order.RecordTypeId,Product2Id,Quantity,ListPrice,UnitPrice FROM OrderItem WHERE Id IN :oiIdList]){
            for(OrderItem oi : oiList){
                o.AccountId=oi.Order.AccountId;
                o.RecordTypeId=oi.Order.RecordTypeId;
                oiInsertList.add(new OrderItem(Product2Id=oi.Product2Id,Quantity=oi.Quantity,ListPrice=oi.ListPrice,UnitPrice=oi.UnitPrice));
                oi.CTBR_OutOfStockDuringApproval__c=false;
            }
            update oiList;
        }
        try{           
            if(!oiInsertList.isEmpty()){
                insert o;
                for(OrderItem oi : oiInsertList){
                    oi.OrderId=o.Id;
                }
                insert oiInsertList;
            }
        }catch(Exception e){
            throw new AuraHandledException(e.getMessage());
        }
        return o;
    }

    @AuraEnabled(cacheable=false)
    public static void approveOrder(String orderId){
        Order o = new Order(Id=orderId,NATT_Order_Status__c='Customer Approved');
        List<OrderItem> oiList = new List<OrderItem>([SELECT Id FROM OrderItem WHERE CTBR_QuantityAvailable__c=0 AND OrderId=:orderId]);
        if(!oiLIst.isEmpty()){
            for(OrderItem oi : oiList){
                oi.CTBR_OutOfStockDuringApproval__c=true;
            }
            update oiList;
        }
        update o;
    }
}