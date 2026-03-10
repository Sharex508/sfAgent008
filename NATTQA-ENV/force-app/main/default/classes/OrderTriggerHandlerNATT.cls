public class OrderTriggerHandlerNATT extends OrderTriggerHandlerAbstract {
    public static boolean firstRun=true;
    public override void handleBeforeInsert(List<SObject> trgNewList){
        List<Order> newList = (List<Order>)trgNewList;
        for(Order o : newList){
            o.NATT_Billing_Address__c=o.NATT_Opp_Billing_Address_Id__c;
            o.NATT_Shipping_Address__c=o.NATT_Opp_Shipping_Address_Id__c;
            // NATT Order Before Save - Flow
            if(o.Type == 'Amendment' && String.isBlank(o.NATT_JDE_Sales_Order_Number__c)){
                o.NATT_JDE_Sales_Order_Number__c = o.NATT_Original_JDE_Sales_Order__c;
            }
        }        
    }
    public override void handleBeforeUpdate(Map<Id,Sobject> trgOldMap, Map<Id,SObject> trgNewMap){
        Map<Id,Order> newMap = (Map<Id,Order>)trgNewMap;
        Map<Id,Order> oldMap = (Map<Id,Order>)trgOldMap;  
        Set<Id> removedAccountIdSet = new Set<Id>();
        
        Order oldO;
        for(Order o : newMap.values()){
            removedAccountIdSet.clear();
            oldO = oldMap.get(o.Id);
            // NATT Order Before Save - Flow
            /*if(o.NATT_Product_Number_Change__c != oldo.NATT_Product_Number_Change__c){
                o.NATT_Boomi_Order_Status__c = 'Main Product Number Change';
            }*/
            if(o.AccountId!=oldo.AccountId){
                removedAccountIdSet.add(oldO.AccountId);
            }
            if(o.NATT_End_Customer__c!=oldO.NATT_End_Customer__c){
                removedAccountIdSet.add(oldO.NATT_End_Customer__c);
            }
            if(!removedAccountIdSet.isEmpty()){
                if(removedAccountIdSet.contains(o.NATT_Billing_Address_Account_Id__c)){
                    o.NATT_Billing_Address__c=null;                    
                    o.BillingStreet='';
                    o.BillingCity='';
                    o.BillingState='';
                    o.BillingPostalCode='';
                    o.BillingCountry='';
                }
                if(removedAccountIdSet.contains(o.NATT_Shipping_Address_Account_Id__c)){
                    o.NATT_Shipping_Address__c=null;
                    o.ShippingStreet='';
                    o.ShippingCity='';
                    o.ShippingState='';
                    o.ShippingPostalCode='';
                    o.ShippingCountry='';
                }   
            }
        }
    }
    public override void handleAfterInsert(Map<Id,SObject> trgNewMap){
        if(firstRun){
            Map<Id,Order> newMap = (Map<Id,Order>)trgNewMap;
            List<JDE_Order__e> orderEventList = new List<JDE_Order__e>();
            for(Order o : newMap.values()){
                orderEventList.add(new JDE_Order__e(Order_Id__c=o.Id));
            }            
            if(!orderEventList.isEmpty()){
                EventBus.publish(orderEventList);
            }
            firstRun = false;
        }
    }
    public override void handleAfterUpdate(Map<Id,SObject> trgOldMap, Map<Id,SObject> trgNewMap) {
        List<Order> lstUpdate= new List<Order>();
        List<OrderItem> lstOrderItem = new List<OrderItem>();
        if(firstRun){
            firstRun=false;
            Map<Id,Order> newMap = (Map<Id,Order>)trgNewMap;
            Map<Id,Order> oldMap = (Map<Id,Order>)trgOldMap;            
            Order oldOrder;
            List<JDE_Order__e> orderEventList = new List<JDE_Order__e>();
            for(Order o : newMap.values()){
                oldOrder = oldMap.get(o.Id);
                if(o.NATT_Purchase_Order__c!=oldOrder.NATT_Purchase_Order__c || o.NATT_Requested_Ship_Date__c!=oldOrder.NATT_Requested_Ship_Date__c ||
                   o.NATT_Mark_For_Special_Delivery_Instructi__c!=oldOrder.NATT_Mark_For_Special_Delivery_Instructi__c || o.NATT_End_Customer__c!=oldOrder.NATT_End_Customer__c||
                   o.ShippingStreet!=oldOrder.ShippingStreet||o.ShippingCity!=oldOrder.ShippingCity||o.ShippingState!=oldOrder.ShippingState||
                   o.ShippingPostalCode!=oldOrder.ShippingPostalCode||o.ShippingCountry!=oldOrder.ShippingCountry||o.NATT_Dealer_Comments__c!=oldOrder.NATT_Dealer_Comments__c||
                   o.NATT_Stock__c!=oldOrder.NATT_Stock__c||o.NATT_Shipment_Method__c!=oldOrder.NATT_Shipment_Method__c){
                       orderEventList.add(new JDE_Order__e(Order_Id__c=o.Id));
                }
            }
            if(!orderEventList.isEmpty()){
                EventBus.publish(orderEventList);
            }
            firstRun = false;
        }
        if(CheckRecursive.runOnce()){
            Set<Id> setOrderId = new Set<Id>();
            Set<Id> setId = trgNewMap.keySet();
            for(Order o : [SELECT Id, NATT_Original_Order_Id__c, NATT_JDE_Sales_Order_Number__c, NATT_Original_JDE_Sales_Order__c, Type FROM Order Where Id IN: setId]){
                if(o.Type == 'New'){
                    //Update Original Order Id - NATT Update Original Order Id Flow
                    if(String.isBlank(o.NATT_Original_Order_Id__c)){
                        o.NATT_Original_Order_Id__c = (Id)o.Id;
                        lstUpdate.add(o);
                    }
                    
                    //Update JDE Sales Order # - NATT Update Original JDE Sales Order Number Flow
                    if(!String.isBlank(o.NATT_JDE_Sales_Order_Number__c) && String.isBlank(o.NATT_Original_JDE_Sales_Order__c)){
                        o.NATT_Original_JDE_Sales_Order__c = o.NATT_JDE_Sales_Order_Number__c;
                        lstUpdate.add(o);
                        setOrderId.add(o.Id);
                    }
                }
            }
            if(!setOrderId.isEmpty()){
                for(OrderItem oi : [SELECT Id, NATT_Original_JDE_Sales_Order__c, Order.NATT_JDE_Sales_Order_Number__c FROM OrderItem WHERE NATT_Original_JDE_Sales_Order__c = null AND OrderId IN:setOrderId]){
                    oi.NATT_Original_JDE_Sales_Order__c = oi.Order.NATT_JDE_Sales_Order_Number__c;
                    lstOrderItem.add(oi);
                }
            }
            if(!lstOrderItem.isEmpty()){
                update lstOrderItem;
            }         
            if(!lstUpdate.isEmpty()){
                update lstUpdate;
            }
        }
    }
}