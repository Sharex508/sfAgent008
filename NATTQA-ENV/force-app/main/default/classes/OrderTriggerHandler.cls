public without sharing class OrderTriggerHandler extends TriggerHandlerVirtual{
    static Map<String,OrderRecordTypeHandler> orderRecordTypeHandlerMap = new Map<String,OrderRecordTypeHandler>();
    /*Map which defines record type to handler class
	* order trigger executes and calls mapped handler class*/
    private static Map<String,List<String>> orderRtClassMap = new Map<String,List<String>>{
        'OrderTriggerHandlerNATT' => new List<String>{'NATT_Parts_Order','NATT_Units_Order','NATT_Units_Amendment_Order'}
    };
        
        public OrderTriggerHandler(){
            super(Order.SobjectType);
        }
    
    {
        OrderRecordTypeHandler handler = null;
        Map<String,Schema.RecordTypeInfo> rtInfoMap = Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName();
        for(String className : orderRtClassMap.keySet()){
            handler = new orderRecordTypeHandler();
            handler.recordTypeOperation = (orderTriggerHandlerAbstract)Type.forName(className).newInstance();
            for(String recordType : orderRtClassMap.get(className)){
                orderRecordTypeHandlerMap.put(rtInfoMap.get(recordType).getRecordTypeId(),handler);
            }
        }
    }
    private void splitDataByRecordType(Object oldObject,Object newObject){
        Order orderRecord = null;
        orderRecordTypeHandler rtHandler = null;
        List<sObject> soList = Trigger.isBefore && Trigger.isInsert ? (List<sObject>)newObject : 
        Trigger.isDelete ? ((Map<Id,sObject>) oldObject).values() : 
        ((Map<Id,sObject>)newObject).values();
        Map<Id,sObject> oldMap = oldObject !=null ? (Map<Id,sObject>)oldObject : new Map<Id,sObject>();        
        
        for(sObject orderObject : soList){
            orderRecord = (Order)orderObject;
            if(orderRecordTypeHandlerMap.containsKey(orderRecord.RecordTypeId)){
                rtHandler = orderRecordTypeHandlerMap.get(orderRecord.RecordTypeId);
                if(trigger.isBefore && trigger.isInsert){
                    rtHandler.orderNewList.add(orderRecord);
                }else if(trigger.isDelete){
                    rtHandler.orderOldMap.put(orderRecord.Id,orderRecord);
                }else{
                    rtHandler.orderNewMap.put(orderRecord.Id,orderRecord);
                    rtHandler.orderOldMap.put(orderRecord.Id,(Order)oldMap.get(orderRecord.Id));
                }                
            }
        }
    }
    
    class OrderRecordTypeHandler{
        orderTriggerHandlerAbstract recordTypeOperation {get;set;}
        Map<Id,Order> orderOldMap {get;set;}
        Map<Id,Order> orderNewMap {get;set;}
        List<Order> orderNewList {get;set;}
        OrderRecordTypeHandler() {
            orderNewList = new List<Order>();
            orderNewMap = new Map<Id,Order>();
            orderOldMap = new Map<Id,Order>();
        }
    }
    
    protected override void handleBeforeInsert(List<SObject> newList) {
        orderRecordTypeHandler handler = null;
        splitDataByRecordType(null, newList);
        for(String recordTypeId : orderRecordTypeHandlerMap.keySet()) {
            handler = orderRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.orderNewList.isEmpty()) {
                handler.recordTypeOperation.handleBeforeInsert(handler.orderNewList);
            }
        }
    }
    
    protected override void handleBeforeUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
        orderRecordTypeHandler handler = null;
        splitDataByRecordType(oldMap, newMap);        
        
        for(String recordTypeId : orderRecordTypeHandlerMap.keySet()) {
            handler = orderRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.orderNewMap.isEmpty()) {
                handler.recordTypeOperation.handleBeforeUpdate(handler.orderOldMap, handler.orderNewMap);
            } 
        }
    }
    
    protected override void handleBeforeDelete(Map<Id, SObject> oldMap) {
        orderRecordTypeHandler handler = null;
        splitDataByRecordType(oldMap, null);        
        for(String recordTypeId : orderRecordTypeHandlerMap.keySet()) {
            handler = orderRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.orderOldMap.isEmpty()) {
                handler.recordTypeOperation.handleBeforeDelete(handler.orderOldMap);
            }
        }
    }
    
    protected override void handleAfterInsert(Map<Id, SObject> newMap) {
        orderRecordTypeHandler handler = null;
        splitDataByRecordType(null, newMap);        
        for(String recordTypeId : orderRecordTypeHandlerMap.keySet()) {
            handler = orderRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.orderNewMap.isEmpty()) {
                handler.recordTypeOperation.handleAfterInsert(handler.orderNewMap);
            }
        }
    }  
    
    protected override void handleAfterUpdate(Map<Id,sObject> oldMap,Map<Id,sObject> newMap){
        orderRecordTypeHandler handler = null;
        splitDataByRecordType(oldMap,newMap);
        for(String recordTypeId : orderRecordTypeHandlerMap.keySet()){
            handler = orderRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.orderNewMap.isEmpty()){
                handler.recordTypeOperation.handleAfterUpdate(handler.orderOldMap,handler.orderNewMap);
            }
        }
    }
    
    protected override void handleAfterDelete(Map<Id, SObject> oldMap) {
        orderRecordTypeHandler handler = null;
        splitDataByRecordType(oldMap, null);
        for(String recordTypeId : orderRecordTypeHandlerMap.keySet()) {
            handler = orderRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.orderOldMap.isEmpty()) {
                handler.recordTypeOperation.handleAfterDelete(handler.orderOldMap);
            }
        }
    }
    
    protected override void handleAfterUndelete(Map<Id, SObject> newMap) {
        orderRecordTypeHandler handler = null;
        splitDataByRecordType(null, newMap);
        for(String recordTypeId : orderRecordTypeHandlerMap.keySet()) {
            handler = orderRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.orderNewMap.isEmpty()) {
                handler.recordTypeOperation.handleAfterUndelete(handler.orderNewMap);
            }
        }
    }
}