public without sharing class QuoteLineTriggerHandler extends TriggerHandlerVirtual{
    
    static Map<String,QuoteLineRecordTypeHandler> quoteLineRecordTypeHandlerMap = new Map<String,QuoteLineRecordTypeHandler>();
    
    /*Map which defines record type to handler class quote line trigger executes and calls mapped handler class*/
    private static Map<String,List<String>> quoteLineRtClassMap = new Map<String,List<String>>{
        'QuoteLineTriggerHandlerNATT' => new List<String>{'NATT_Parts_Quote','NATT_Units_Quote','NATT_Internal_Customer','NATT_Units_Quote_Amendment'},
            'QuoteLineTriggerHandlerBluEdge' => new List<String>{'NATT_BluEdge'}
    };
        
        public QuoteLineTriggerHandler(){
            super(SBQQ__QuoteLine__c.SobjectType);
        }
    
    {
        QuoteLineRecordTypeHandler handler = null;
        
        Map<String,Schema.RecordTypeInfo> rtInfoMap = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName();
        for(String className : quoteLineRtClassMap.keySet()){
            handler = new QuoteLineRecordTypeHandler();
            handler.recordTypeOperation = (quoteLineTriggerHandlerAbstract)Type.forName(className).newInstance();
            for(String recordType : quoteLineRtClassMap.get(className)){
                System.debug('recordType'+recordType);
                
                quoteLineRecordTypeHandlerMap.put(rtInfoMap.get(recordType).getRecordTypeId(),handler);
            }
        }
    }   
    
    private void splitDataByRecordType(Object oldObject,Object newObject){
        
        SBQQ__QuoteLine__c quoteLineRecord = null;
        quoteLineRecordTypeHandler rtHandler = null;
        List<sObject> soList = Trigger.isBefore && Trigger.isInsert ? (List<sObject>)newObject : Trigger.isDelete ? ((Map<Id,sObject>) oldObject).values() : ((Map<Id,sObject>)newObject).values();
        Map<Id,sObject> oldMap = oldObject !=null ? (Map<Id,sObject>)oldObject : new Map<Id,sObject>();        
        
        for(sObject quoteLineObject : soList){
            
            quoteLineRecord = (SBQQ__QuoteLine__c)quoteLineObject;
            
            if(quoteLineRecordTypeHandlerMap.containsKey(quoteLineRecord.NATT_Quote_Record_Type_ID__c)){                
                rtHandler = quoteLineRecordTypeHandlerMap.get(quoteLineRecord.NATT_Quote_Record_Type_ID__c);
                if(trigger.isBefore && trigger.isInsert){
                    rtHandler.quoteLineNewList.add(quoteLineRecord);
                }else if(trigger.isDelete){
                    rtHandler.quoteLineOldMap.put(quoteLineRecord.Id,quoteLineRecord);
                }else{
                    rtHandler.quoteLineNewMap.put(quoteLineRecord.Id,quoteLineRecord);
                    rtHandler.quoteLineOldMap.put(quoteLineRecord.Id,(SBQQ__QuoteLine__c)oldMap.get(quoteLineRecord.Id));
                }                
            }
        }
    }
    
    class QuoteLineRecordTypeHandler{
        
        quoteLineTriggerHandlerAbstract recordTypeOperation {get;set;}
        Map<Id,SBQQ__QuoteLine__c> quoteLineOldMap {get;set;}
        Map<Id,SBQQ__QuoteLine__c> quoteLineNewMap {get;set;}
        List<SBQQ__QuoteLine__c> quoteLineNewList {get;set;}
        
        QuoteLineRecordTypeHandler() {
            quoteLineNewList = new List<SBQQ__QuoteLine__c>();
            quoteLineNewMap = new Map<Id,SBQQ__QuoteLine__c>();
            quoteLineOldMap = new Map<Id,SBQQ__QuoteLine__c>();
        }
    } 
    
    protected override void handleBeforeInsert(List<SObject> newList) {
        
        quoteLineRecordTypeHandler handler = null;
        splitDataByRecordType(null, newList);
        
        for(String recordTypeId : quoteLineRecordTypeHandlerMap.keySet()) {
            handler = quoteLineRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.quoteLineNewList.isEmpty()) {
                handler.recordTypeOperation.handleBeforeInsert(handler.quoteLineNewList);
            }
        }
    }
    
    protected override void handleBeforeUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
        
        quoteLineRecordTypeHandler handler = null;       
        splitDataByRecordType(oldMap, newMap);        
        
        for(String recordTypeId : quoteLineRecordTypeHandlerMap.keySet()) {
            handler = quoteLineRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.quoteLineNewMap.isEmpty()) {
                handler.recordTypeOperation.handleBeforeUpdate(handler.quoteLineOldMap, handler.quoteLineNewMap);
            } 
        }
    }
    
    protected override void handleBeforeDelete(Map<Id, SObject> oldMap) {
        
    }
    
    protected override void handleAfterInsert(Map<Id, SObject> newMap) {
        
    }  
    
    protected override void handleAfterUpdate(Map<Id,sObject> oldMap,Map<Id,sObject> newMap){
        
    }
    
    protected override void handleAfterDelete(Map<Id, SObject> oldMap) {
        
    }
    
    protected override void handleAfterUndelete(Map<Id, SObject> newMap) {
        
    }
}