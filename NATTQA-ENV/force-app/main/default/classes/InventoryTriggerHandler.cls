public without sharing class InventoryTriggerHandler {
    
    public static void onAfterInsert(Map<Id,NATT_Inventory__c> trgNewMap){
        Set<String> orderIdSet = new Set<String>();
        List<NATT_Extended_Warranty__c> insertList = new List<NATT_Extended_Warranty__c>();
        
        for(NATT_Inventory__c inv : trgNewMap.values()){
            //Update: NATT_Extended_Warranty_Code__c is populated with Quote Number
            orderIdSet.add(inv.NATT_Extended_Warranty_Code__c);
        }
        orderIdSet.remove(null);
        Map<String,List<OrderItem>> orderToOiMap = new Map<String,List<OrderItem>>();
        //find all the bluedge(warranty) items that are ready to be picked up
        for(OrderItem oi : [SELECT Id,Quantity,OrderId,Order.NATT_Quote_Name__c,NATT_Tavant_Id__c,NATT_Months__c,NATT_Hours__c, NATT_Deductibles2__c FROM OrderItem WHERE Order.NATT_Quote_Name__c in :orderIdSet]){
            if(!orderToOiMap.containsKey(oi.Order.NATT_Quote_Name__c)){
                orderToOiMap.put(oi.Order.NATT_Quote_Name__c,new List<OrderItem>());                
           }
            orderToOiMap.get(oi.Order.NATT_Quote_Name__c).add(oi);
        }
        for(NATT_Inventory__c inv : trgNewMap.values()){
            if(orderToOiMap.containsKey(inv.NATT_Extended_Warranty_Code__c)){
                for(OrderItem oItem : orderToOiMap.get(inv.NATT_Extended_Warranty_Code__c)){
                    //if(oItem.Quantity>0){
                        //for(integer i=0; i<oItem.Quantity; i++){
                            insertList.add(new NATT_Extended_Warranty__c(Action__c='Create',PolicyCode__c=oItem.NATT_Tavant_Id__c,UnitSerialNumber__c=inv.NATT_Serial_Number__c,Term__c=oItem.NATT_Months__c,Usage__c=oItem.NATT_Hours__c,Deductibles__c=oItem.NATT_Deductibles2__c,NATT_Inventory__c=inv.Id));
                        //}
                    //}
                }
            }
        }
        if(!insertList.isEmpty()){
            insert insertList;
        }
    }
    /*
    public static void onAfterUpdate(List<NATT_Inventory__c> trgNewList, Map<Id,NATT_Inventory__c> trgOldMap){
        Set<String> orderIdSet = new Set<String>();
        List<NATT_Extended_Warranty__c> insertList = new List<NATT_Extended_Warranty__c>();
        for(NATT_Inventory__c inv : trgNewList){
            if(inv.NATT_Extended_Warranty_Code__c != trgOldMap.get(inv.Id).NATT_Extended_Warranty_Code__c){
                orderIdSet.add(inv.NATT_Extended_Warranty_Code__c);
            }
        }
        orderIdSet.remove(null);
        Map<String,List<SBQQ__QuoteLine__c>> quotetoQLMap = new Map<String,List<SBQQ__QuoteLine__c>>();
        for(SBQQ__QuoteLine__c ql : [SELECT Id,SBQQ__Quantity__c,NATT_Serial_Number__c, NATT_Tavant_Id__c,NATT_Months__c,NATT_Hours__c, NATT_Deductibles2__c, SBQQ__Quote__r.Name FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__r.Name in :orderIdSet]){
            if(!quotetoQLMap.containsKey(ql.SBQQ__Quote__r.Name)){
                quotetoQLMap.put(ql.SBQQ__Quote__r.Name,new List<SBQQ__QuoteLine__c>());                
           }
            quotetoQLMap.get(ql.SBQQ__Quote__r.Name).add(ql);
        }
        for(NATT_Inventory__c inv : trgNewList){
            if(quotetoQLMap.containsKey(inv.NATT_Extended_Warranty_Code__c)){
                for(SBQQ__QuoteLine__c ql: quotetoQLMap.get(inv.NATT_Extended_Warranty_Code__c)){
                    //if(oItem.Quantity>0){
                        //for(integer i=0; i<oItem.Quantity; i++){
                            insertList.add(new NATT_Extended_Warranty__c(Action__c='Create',
                                                                         PolicyCode__c=ql.NATT_Tavant_Id__c,
                                                                         UnitSerialNumber__c=ql.NATT_Serial_Number__c,
                                                                         Term__c=ql.NATT_Months__c,
                                                                         Usage__c=ql.NATT_Hours__c,
                                                                         Deductibles__c=ql.NATT_Deductibles2__c,
                                                                         NATT_Inventory__c=inv.Id));
                        //}
                    //}
                }
            }
        }
        if(!insertList.isEmpty()){
            insert insertList;
        }
    
    }*/
}