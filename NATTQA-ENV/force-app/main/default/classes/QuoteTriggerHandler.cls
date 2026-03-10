public without sharing class QuoteTriggerHandler extends TriggerHandlerVirtual{
    static Map<String,QuoteRecordTypeHandler> quoteRecordTypeHandlerMap = new Map<String,QuoteRecordTypeHandler>();
    /*Map which defines record type to handler class
* quote trigger executes and calls mapped handler class*/
    
    private static Map<String,List<String>> quoteRtClassMap = new Map<String,List<String>>{
        'QuoteTriggerHandlerNATT' => new List<String>{'NATT_BluEdge','NATT_eSolutions','NATT_Parts_Quote','NATT_Units_Quote','NATT_Internal_Customer','NATT_Units_Quote_Amendment','MX_Units_Quote','CTM_Units_Quote_Approved','NATT_Direct_Sales_Quote_Amendment','NATT_Direct_Sales'}
    };
        
        public QuoteTriggerHandler(){
            super(SBQQ__Quote__c.SobjectType);
        }
    
    {
        QuoteRecordTypeHandler handler = null;
        Map<String,Schema.RecordTypeInfo> rtInfoMap = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName();
        for(String className : quoteRtClassMap.keySet()){
            handler = new quoteRecordTypeHandler();
            handler.recordTypeOperation = (quoteTriggerHandlerAbstract)Type.forName(className).newInstance();
            for(String recordType : quoteRtClassMap.get(className)){
                quoteRecordTypeHandlerMap.put(rtInfoMap.get(recordType).getRecordTypeId(),handler);
            }
        }
    }
    
    private void splitDataByRecordType(Object oldObject,Object newObject){
        SBQQ__Quote__c quoteRecord = null;
        quoteRecordTypeHandler rtHandler = null;
        List<sObject> soList = Trigger.isBefore && Trigger.isInsert ? (List<sObject>)newObject : 
        Trigger.isDelete ? ((Map<Id,sObject>) oldObject).values() : 
        ((Map<Id,sObject>)newObject).values();
        Map<Id,sObject> oldMap = oldObject !=null ? (Map<Id,sObject>)oldObject : new Map<Id,sObject>();        
        
        for(sObject quoteObject : soList){
            quoteRecord = (SBQQ__Quote__c)quoteObject;
            if(quoteRecordTypeHandlerMap.containsKey(quoteRecord.RecordTypeId)){
                rtHandler = quoteRecordTypeHandlerMap.get(quoteRecord.RecordTypeId);
                if(trigger.isBefore && trigger.isInsert){
                    rtHandler.quoteNewList.add(quoteRecord);
                }else if(trigger.isDelete){
                    rtHandler.quoteOldMap.put(quoteRecord.Id,quoteRecord);
                }else{
                    rtHandler.quoteNewMap.put(quoteRecord.Id,quoteRecord);
                    rtHandler.quoteOldMap.put(quoteRecord.Id,(SBQQ__Quote__c)oldMap.get(quoteRecord.Id));
                }                
            }
        }
    }
    
    class QuoteRecordTypeHandler{
        quoteTriggerHandlerAbstract recordTypeOperation {get;set;}
        Map<Id,SBQQ__Quote__c> quoteOldMap {get;set;}
        Map<Id,SBQQ__Quote__c> quoteNewMap {get;set;}
        List<SBQQ__Quote__c> quoteNewList {get;set;}
        QuoteRecordTypeHandler() {
            quoteNewList = new List<SBQQ__Quote__c>();
            quoteNewMap = new Map<Id,SBQQ__Quote__c>();
            quoteOldMap = new Map<Id,SBQQ__Quote__c>();
        }
    }
    
    protected override void handleBeforeInsert(List<SObject> newList) {
        quoteRecordTypeHandler handler = null;
        splitDataByRecordType(null, newList);
        for(String recordTypeId : quoteRecordTypeHandlerMap.keySet()) {
            handler = quoteRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.quoteNewList.isEmpty()) {
                handler.recordTypeOperation.handleBeforeInsert(handler.quoteNewList);
            }
        }
    }
    
    protected override void handleBeforeUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
        quoteRecordTypeHandler handler = null;
        splitDataByRecordType(oldMap, newMap);        
        
        for(String recordTypeId : quoteRecordTypeHandlerMap.keySet()) {
            handler = quoteRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.quoteNewMap.isEmpty()) {
                handler.recordTypeOperation.handleBeforeUpdate(handler.quoteOldMap, handler.quoteNewMap);
            } 
        }
    }
    
    protected override void handleBeforeDelete(Map<Id, SObject> oldMap) {
        quoteRecordTypeHandler handler = null;
        splitDataByRecordType(oldMap, null);        
        for(String recordTypeId : quoteRecordTypeHandlerMap.keySet()) {
            handler = quoteRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.quoteOldMap.isEmpty()) {
                handler.recordTypeOperation.handleBeforeDelete(handler.quoteOldMap);
            }
        }
    }
    
    protected override void handleAfterInsert(Map<Id, SObject> newMap) {
        quoteRecordTypeHandler handler = null;
        splitDataByRecordType(null, newMap);        
        for(String recordTypeId : quoteRecordTypeHandlerMap.keySet()) {
            handler = quoteRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.quoteNewMap.isEmpty()) {
                handler.recordTypeOperation.handleAfterInsert(handler.quoteNewMap);
            }
        }
    }  
    
    protected override void handleAfterUpdate(Map<Id,sObject> oldMap,Map<Id,sObject> newMap){
        quoteRecordTypeHandler handler = null;
        splitDataByRecordType(oldMap,newMap);
        for(String recordTypeId : quoteRecordTypeHandlerMap.keySet()){
            handler = quoteRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.quoteNewMap.isEmpty()){
                handler.recordTypeOperation.handleAfterUpdate(handler.quoteOldMap,handler.quoteNewMap);
            }
        }
    }
    
    protected override void handleAfterDelete(Map<Id, SObject> oldMap) {
        quoteRecordTypeHandler handler = null;
        splitDataByRecordType(oldMap, null);
        for(String recordTypeId : quoteRecordTypeHandlerMap.keySet()) {
            handler = quoteRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.quoteOldMap.isEmpty()) {
                handler.recordTypeOperation.handleAfterDelete(handler.quoteOldMap);
            }
        }
    }
    
    protected override void handleAfterUndelete(Map<Id, SObject> newMap) {
        quoteRecordTypeHandler handler = null;
        splitDataByRecordType(null, newMap);
        for(String recordTypeId : quoteRecordTypeHandlerMap.keySet()) {
            handler = quoteRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.quoteNewMap.isEmpty()) {
                handler.recordTypeOperation.handleAfterUndelete(handler.quoteNewMap);
            }
        }
    }
}