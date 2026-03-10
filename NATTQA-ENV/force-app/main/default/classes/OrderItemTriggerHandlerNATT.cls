public without sharing class OrderItemTriggerHandlerNATT {
    public static void onBeforeInsert(List<OrderItem> trgNew){
        Set<Id> setId = new Set<Id>();
               
        for(OrderItem oi : trgNew){
            if(oi.ListPrice==null){
                oi.ListPrice=oi.UnitPrice;
            }
            setId.add(oi.OrderId);
        }
        
        Map<Id, Order> mapOrder = new Map<Id, Order>([SELECT Id, NATT_Original_Order_Id__c, Type, NATT_JDE_Sales_Order_Number__c, RecordType.DeveloperName FROM Order WHERE Id IN: setId]);
        for(OrderItem oi : trgNew){
            //NATT Update Original Order Id Item - Workflow
            if(String.isBlank(oi.NATT_Original_Order_Id__c) && mapOrder.get(oi.OrderId).Type == 'New' && mapOrder.get(oi.OrderId).RecordType.DeveloperName.contains('NATT_Units')){
                oi.NATT_Original_Order_Id__c = (Id)oi.OrderId;
            }
            else if(String.isBlank(oi.NATT_Original_Order_Id__c) && mapOrder.get(oi.OrderId).RecordType.DeveloperName.contains('NATT_Units')){
                 oi.NATT_Original_Order_Id__c = mapOrder.get(oi.OrderId).NATT_Original_Order_Id__c;
            }
        }        
    }
    
    public static void onAfterInsert(List<OrderItem> trgNew){
        Map<Id,OrderItem> oiUpdateMap = new Map<Id,OrderItem>();
        Set<Id> hasCoreItemSet = new Set<Id>();
        List<NATT_Extended_Warranty__c> insertList = new List<NATT_Extended_Warranty__c>();
        Set<String> orderIdSet = new Set<String>();
        
        for(OrderItem oi : trgNew){          
            if(String.isBlank(oi.NATT_OrderItemKeyId__c)){
                if(oi.NATT_IsRushFee__c){
                    //Boomi integration requirement since an SFDC originated order item is not pulled for rush fee                    
                    oiUpdateMap.put(oi.Id,new OrderItem(Id=oi.Id,NATT_OrderItemKeyId__c='SC-'+oi.NATT_OrderNumberSFDC__c+'|990'));    
                }else{
                    oiUpdateMap.put(oi.Id,new OrderItem(Id=oi.Id,NATT_OrderItemKeyId__c=oi.Id));
                }
                
                if(oi.NATT_HasCore__c){
                    hasCoreItemSet.add(oi.OrderId);
                }
            }
            if(!String.isBlank(oi.NATT_Serial_Number__c)){
                //orderIdSet.add(oi.NATT_Serial_Number__c);
                //for(NATT_Inventory__c inv : [SELECT Id,NATT_Serial_Number__c FROM NATT_Inventory__c WHERE NATT_Serial_Number__c in :orderIdSet]){
                    insertList.add(new NATT_Extended_Warranty__c(Action__c='Create',
                                                                 PolicyCode__c=oi.NATT_Tavant_Id__c,
                                                                 UnitSerialNumber__c=oi.NATT_Serial_Number__c,
                                                                 Term__c=oi.NATT_Months__c,
                                                                 Usage__c=oi.NATT_Hours__c,
                                                                 Deductibles__c=oi.NATT_Deductibles2__c,
                                                                 NATT_Inventory__c=oi.NATT_Inventory__c));
                //}
            }   
        }
        if(!insertList.isEmpty()){
            insert insertList;
        }
        
        if(!hasCoreItemSet.isEmpty()){            
            Map<Id,Map<String,Id>> pIdToPartNumberMap = new Map<Id,Map<String,Id>>();
            List<Order> oList = new List<Order>([SELECT Id,(SELECT Id,Product2.NATT_P_N__c,Product2.NATT_CoreItem_P_N__c,NATT_HasCore__c FROM OrderItems) FROM Order WHERE Id in :hasCoreItemSet]);
            for(Order o : oList){
                pIdToPartNumberMap.put(o.Id,new Map<String,Id>());
                for(OrderItem oi : o.OrderItems){
                    if(oi.NATT_HasCore__c){
                        pIdToPartNumberMap.get(o.Id).put(oi.Product2.NATT_CoreItem_P_N__c,oi.Id);
                    }
                }
            }
            
            for(Order o : oList){                
                for(OrderItem oi : o.OrderItems){
                    if(!oi.NATT_HasCore__c && pIdToPartNumberMap.get(o.Id).containsKey(oi.Product2.NATT_P_N__c)){
                        if(oiUpdateMap.containsKey(oi.Id)){
                            oiUpdateMap.get(oi.Id).NATT_OrderItemKeyId__c=pIdToPartNumberMap.get(o.Id).get(oi.Product2.NATT_P_N__c)+'-C';
                        }else{
                            oiUpdateMap.put(oi.Id,new OrderItem(Id=oi.Id,NATT_OrderItemKeyId__c=pIdToPartNumberMap.get(o.Id).get(oi.Product2.NATT_P_N__c)+'-C'));
                        }                        
                    }
                }
            }
        }
        if(!oiUpdateMap.isEmpty()){
            update oiUpdateMap.values();
        }
    }
}