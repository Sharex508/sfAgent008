public without sharing class ContactTriggerHandler extends TriggerHandlerVirtual {

    static Map<String,RecordTypeHandler> recordTypeHandlerMap = new Map<String,RecordTypeHandler>();

    private static Map<String,List<String>> classMap = new Map<String,List<String>>{
        'ContactTriggerHandlerNATT' => new List<String>{'NATT_Dealer','NATT_Competitor', 'NATT_End_Customer','NATT_Direct_Sell_Internal', 'MX_Dealer','NATT_Inactive_Contact'}
         //   'ContactTriggerHandlerMX' => new List<String>{'MX_Dealer','MX_Customer', 'MX_Competitor'}
    };
    
    public ContactTriggerHandler(){
        super(Contact.SobjectType);
    }

    {
        RecordTypeHandler handler = null;
        Map<String,Schema.RecordTypeInfo> rtInfoMap = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName();
        
        for (String className : classMap.keySet()) {
            handler = new RecordTypeHandler();
            handler.recordTypeOperation = (ContactTriggerHandlerAbstract)Type.forName(className).newInstance();
            
            for (String recordType : classMap.get(className)) {
                recordTypeHandlerMap.put(rtInfoMap.get(recordType).getRecordTypeId(),handler);
            }
        }
    }

    private void splitDataByRecordType(Object oldObject,Object newObject){
        Contact record = null;
        RecordTypeHandler rtHandler = null;
        List<sObject> soList = Trigger.isBefore && Trigger.isInsert ? (List<sObject>)newObject : 
        Trigger.isDelete ? ((Map<Id,sObject>) oldObject).values() : 
        ((Map<Id,sObject>)newObject).values();
        Map<Id,sObject> oldMap = oldObject !=null ? (Map<Id,sObject>)oldObject : new Map<Id,sObject>();        
        
        for (sObject obj : soList) {
            record = (Contact) obj;
            if (recordTypeHandlerMap.containsKey(record.RecordTypeId)) {
                rtHandler = recordTypeHandlerMap.get(record.RecordTypeId);
                if (trigger.isBefore && trigger.isInsert) {
                    rtHandler.newList.add(record);
                } else if (trigger.isDelete) {
                    rtHandler.oldMap.put(record.Id,record);
                } else {
                    rtHandler.newMap.put(record.Id,record);
                    rtHandler.oldMap.put(record.Id,(Contact)oldMap.get(record.Id));
                }                
            }
        }
    }
    
    class RecordTypeHandler {
        ContactTriggerHandlerAbstract recordTypeOperation {get;set;}
        Map<Id,Contact> oldMap {get;set;}
        Map<Id,Contact> newMap {get;set;}
        List<Contact> newList {get;set;}
        RecordTypeHandler() {
            newList = new List<Contact>();
            newMap = new Map<Id,Contact>();
            oldMap = new Map<Id,Contact>();
        }
    }
    protected override void handleBeforeInsert(List<SObject> newList) {
        RecordTypeHandler handler = null;
        splitDataByRecordType(null, newList);
        for(String recordTypeId : recordTypeHandlerMap.keySet()) {
            handler = recordTypeHandlerMap.get(recordTypeId);
            if(!handler.newList.isEmpty()) {
                handler.recordTypeOperation.handleBeforeInsert(handler.newList);
            }
        }
    }
    
    protected override void handleBeforeUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
        RecordTypeHandler handler = null;
        splitDataByRecordType(oldMap, newMap);        
        
        for(String recordTypeId : recordTypeHandlerMap.keySet()) {
            handler = recordTypeHandlerMap.get(recordTypeId);
            if(!handler.newMap.isEmpty()) {
                handler.recordTypeOperation.handleBeforeUpdate(handler.oldMap, handler.newMap);
            } 
        }
    }
    
    protected override void handleBeforeDelete(Map<Id, SObject> oldMap) {
        RecordTypeHandler handler = null;
        splitDataByRecordType(oldMap, null);        
        for(String recordTypeId : recordTypeHandlerMap.keySet()) {
            handler = recordTypeHandlerMap.get(recordTypeId);
            if(!handler.oldMap.isEmpty()) {
                handler.recordTypeOperation.handleBeforeDelete(handler.oldMap);
            }
        }
    }
    
    protected override void handleAfterInsert(Map<Id, SObject> newMap) {
        RecordTypeHandler handler = null;
        splitDataByRecordType(null, newMap);

        for (String recordTypeId : recordTypeHandlerMap.keySet()) {
            handler = recordTypeHandlerMap.get(recordTypeId);
            
            if (!handler.newMap.isEmpty()) {
                handler.recordTypeOperation.handleAfterInsert(handler.newMap);
            }
        }
    }

    protected override void handleAfterUpdate(Map<Id,SObject> oldMap,Map<Id,SObject> newMap) {
        RecordTypeHandler handler = null;
        splitDataByRecordType(oldMap,newMap);

        for (String recordTypeId : recordTypeHandlerMap.keySet()) {
            handler = recordTypeHandlerMap.get(recordTypeId);
            
            if (!handler.newMap.isEmpty()) {
                handler.recordTypeOperation.handleAfterUpdate(handler.oldMap, handler.newMap);
            }
        }
    }

    protected override void handleAfterDelete(Map<Id, SObject> oldMap) {
        RecordTypeHandler handler = null;
        splitDataByRecordType(oldMap, null);

        for (String recordTypeId : recordTypeHandlerMap.keySet()) {
            handler = recordTypeHandlerMap.get(recordTypeId);
            
            if (!handler.oldMap.isEmpty()) {
                handler.recordTypeOperation.handleAfterDelete(handler.oldMap);
            }
        }
    }    
        
    protected override void handleAfterUndelete(Map<Id, SObject> newMap) {
        RecordTypeHandler handler = null;
        splitDataByRecordType(null, newMap);
        for(String recordTypeId : recordTypeHandlerMap.keySet()) {
            handler = recordTypeHandlerMap.get(recordTypeId);
            if(!handler.newMap.isEmpty()) {
                handler.recordTypeOperation.handleAfterUndelete(handler.newMap);
            }
        }
    }
    
}