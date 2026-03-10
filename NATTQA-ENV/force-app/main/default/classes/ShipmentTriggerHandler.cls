public without sharing class ShipmentTriggerHandler extends TriggerHandlerVirtual{
    static Map<String,ShipmentRecordTypeHandler> shipmentRecordTypeHandlerMap = new Map<String,ShipmentRecordTypeHandler>();
    /*Map which defines record type to handler class
* shipment trigger executes and calls mapped handler class*/
    
    private static Map<String,List<String>> shipmentRtClassMap = new Map<String,List<String>>{
        'ShipmentTriggerHandlerNATT' => new List<String>{'NATT_Parts_Shipment'}
    };
        
        public ShipmentTriggerHandler(){
            super(Shipment.SobjectType);
        }
    
    {
        ShipmentRecordTypeHandler handler = null;
        Map<String,Schema.RecordTypeInfo> rtInfoMap = Schema.SObjectType.Shipment.getRecordTypeInfosByDeveloperName();
        for(String className : shipmentRtClassMap.keySet()){
            handler = new ShipmentRecordTypeHandler();
            handler.recordTypeOperation = (shipmentTriggerHandlerAbstract)Type.forName(className).newInstance();
            for(String recordType : shipmentRtClassMap.get(className)){
                shipmentRecordTypeHandlerMap.put(rtInfoMap.get(recordType).getRecordTypeId(),handler);
            }
        }
    }
    
    private void splitDataByRecordType(Object oldObject,Object newObject){
        Shipment shipmentRecord = null;
        shipmentRecordTypeHandler rtHandler = null;
        List<sObject> soList = Trigger.isBefore && Trigger.isInsert ? (List<sObject>)newObject : 
        Trigger.isDelete ? ((Map<Id,sObject>) oldObject).values() : 
        ((Map<Id,sObject>)newObject).values();
        Map<Id,sObject> oldMap = oldObject !=null ? (Map<Id,sObject>)oldObject : new Map<Id,sObject>();        
        
        for(sObject shipmentObject : soList){
            shipmentRecord = (Shipment)shipmentObject;
            if(shipmentRecordTypeHandlerMap.containsKey(shipmentRecord.RecordTypeId)){
                rtHandler = shipmentRecordTypeHandlerMap.get(shipmentRecord.RecordTypeId);
                if(trigger.isBefore && trigger.isInsert){
                    rtHandler.shipmentNewList.add(shipmentRecord);
                }else if(trigger.isDelete){
                    rtHandler.shipmentOldMap.put(shipmentRecord.Id,shipmentRecord);
                }else{
                    rtHandler.shipmentNewMap.put(shipmentRecord.Id,shipmentRecord);
                    rtHandler.shipmentOldMap.put(shipmentRecord.Id,(Shipment)oldMap.get(shipmentRecord.Id));
                }                
            }
        }
    }
    
    class ShipmentRecordTypeHandler{
        shipmentTriggerHandlerAbstract recordTypeOperation {get;set;}
        Map<Id,Shipment> shipmentOldMap {get;set;}
        Map<Id,Shipment> shipmentNewMap {get;set;}
        List<Shipment> shipmentNewList {get;set;}
        ShipmentRecordTypeHandler() {
            shipmentNewList = new List<Shipment>();
            shipmentNewMap = new Map<Id,Shipment>();
            shipmentOldMap = new Map<Id,Shipment>();
        }
    }
    
    protected override void handleBeforeInsert(List<SObject> newList) {
        shipmentRecordTypeHandler handler = null;
        splitDataByRecordType(null, newList);
        for(String recordTypeId : shipmentRecordTypeHandlerMap.keySet()) {
            handler = shipmentRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.shipmentNewList.isEmpty()) {
                handler.recordTypeOperation.handleBeforeInsert(handler.shipmentNewList);
            }
        }
    }
    
    protected override void handleBeforeUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
        shipmentRecordTypeHandler handler = null;
        splitDataByRecordType(oldMap, newMap);        
        
        for(String recordTypeId : shipmentRecordTypeHandlerMap.keySet()) {
            handler = shipmentRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.shipmentNewMap.isEmpty()) {
                handler.recordTypeOperation.handleBeforeUpdate(handler.shipmentOldMap, handler.shipmentNewMap);
            } 
        }
    }
    
    protected override void handleBeforeDelete(Map<Id, SObject> oldMap) {
        shipmentRecordTypeHandler handler = null;
        splitDataByRecordType(oldMap, null);        
        for(String recordTypeId : shipmentRecordTypeHandlerMap.keySet()) {
            handler = shipmentRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.shipmentOldMap.isEmpty()) {
                handler.recordTypeOperation.handleBeforeDelete(handler.shipmentOldMap);
            }
        }
    }
    
    protected override void handleAfterInsert(Map<Id, SObject> newMap) {
        ShipmentRecordTypeHandler handler = null;
        splitDataByRecordType(null, newMap);        
        for(String recordTypeId : shipmentRecordTypeHandlerMap.keySet()) {
            handler = shipmentRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.shipmentNewMap.isEmpty()) {
                handler.recordTypeOperation.handleAfterInsert(handler.shipmentNewMap);
            }
        }
    }  
    
    protected override void handleAfterUpdate(Map<Id,sObject> oldMap,Map<Id,sObject> newMap){
        shipmentRecordTypeHandler handler = null;
        splitDataByRecordType(oldMap,newMap);
        for(String recordTypeId : shipmentRecordTypeHandlerMap.keySet()){
            handler = shipmentRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.shipmentNewMap.isEmpty()){
                handler.recordTypeOperation.handleAfterUpdate(handler.shipmentOldMap,handler.shipmentNewMap);
            }
        }
    }
    
    protected override void handleAfterDelete(Map<Id, SObject> oldMap) {
        shipmentRecordTypeHandler handler = null;
        splitDataByRecordType(oldMap, null);
        for(String recordTypeId : shipmentRecordTypeHandlerMap.keySet()) {
            handler = shipmentRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.shipmentOldMap.isEmpty()) {
                handler.recordTypeOperation.handleAfterDelete(handler.shipmentOldMap);
            }
        }
    }
    
    protected override void handleAfterUndelete(Map<Id, SObject> newMap) {
        ShipmentRecordTypeHandler handler = null;
        splitDataByRecordType(null, newMap);
        for(String recordTypeId : shipmentRecordTypeHandlerMap.keySet()) {
            handler = shipmentRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.shipmentNewMap.isEmpty()) {
                handler.recordTypeOperation.handleAfterUndelete(handler.shipmentNewMap);
            }
        }
    }
}