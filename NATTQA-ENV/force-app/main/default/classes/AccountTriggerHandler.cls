public without sharing class AccountTriggerHandler extends TriggerHandlerVirtual{
    static Map<String,AccountRecordTypeHandler> accountRecordTypeHandlerMap = new Map<String,AccountRecordTypeHandler>();
    /*Map which defines record type to handler class
* Account trigger executes and calls mapped handler class*/
    private static Map<String,List<String>> AccountRtClassMap = new Map<String,List<String>>{
        'AccountTriggerHandlerNATT' => new List<String>{'NATT_Competitor','Customer','Dealer','MX_Dealer','NATT_OEM','NATT_Group_Ownership','Internal'}
    };
        
        public AccountTriggerHandler(){
            super(Account.SobjectType);
        }
    
    {
        AccountRecordTypeHandler handler = null;
        Map<String,Schema.RecordTypeInfo> rtInfoMap = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        for(String className : AccountRtClassMap.keySet()){
            handler = new AccountRecordTypeHandler();
            handler.recordTypeOperation = (AccountTriggerHandlerAbstract)Type.forName(className).newInstance();
            for(String recordType : AccountRtClassMap.get(className)){
                AccountRecordTypeHandlerMap.put(rtInfoMap.get(recordType).getRecordTypeId(),handler);
            }
        }
    }
    private void splitDataByRecordType(Object oldObject,Object newObject){
        Account AccountRecord = null;
        AccountRecordTypeHandler rtHandler = null;
        List<sObject> soList = Trigger.isBefore && Trigger.isInsert ? (List<sObject>)newObject : 
        Trigger.isDelete ? ((Map<Id,sObject>) oldObject).values() : 
        ((Map<Id,sObject>)newObject).values();
        Map<Id,sObject> oldMap = oldObject !=null ? (Map<Id,sObject>)oldObject : new Map<Id,sObject>();        
        
        for(sObject AccountObject : soList){
            AccountRecord = (Account)AccountObject;
            if(accountRecordTypeHandlerMap.containsKey(AccountRecord.RecordTypeId)){
                rtHandler = AccountRecordTypeHandlerMap.get(AccountRecord.RecordTypeId);
                if(trigger.isBefore && trigger.isInsert){
                    rtHandler.AccountNewList.add(AccountRecord);
                }else if(trigger.isDelete){
                    rtHandler.AccountOldMap.put(AccountRecord.Id,AccountRecord);
                }else{
                    rtHandler.AccountNewMap.put(AccountRecord.Id,AccountRecord);
                    rtHandler.AccountOldMap.put(AccountRecord.Id,(Account)oldMap.get(AccountRecord.Id));
                }                
            }
        }
    }
    
    class AccountRecordTypeHandler{
        AccountTriggerHandlerAbstract recordTypeOperation {get;set;}
        Map<Id,Account> accountOldMap {get;set;}
        Map<Id,Account> accountNewMap {get;set;}
        List<Account> accountNewList {get;set;}
        AccountRecordTypeHandler() {
            accountNewList = new List<Account>();
            accountNewMap = new Map<Id,Account>();
            accountOldMap = new Map<Id,Account>();
        }
    }
    
    protected override void handleBeforeInsert(List<SObject> newList) {
        AccountRecordTypeHandler handler = null;
        splitDataByRecordType(null, newList);
        for(String recordTypeId : AccountRecordTypeHandlerMap.keySet()) {
            handler = AccountRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.AccountNewList.isEmpty()) {
                handler.recordTypeOperation.handleBeforeInsert(handler.AccountNewList);
            }
        }
    }
    
    protected override void handleBeforeUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
        AccountRecordTypeHandler handler = null;
        splitDataByRecordType(oldMap, newMap);        
        
        for(String recordTypeId : accountRecordTypeHandlerMap.keySet()) {
            handler = accountRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.AccountNewMap.isEmpty()) {
                handler.recordTypeOperation.handleBeforeUpdate(handler.accountOldMap, handler.accountNewMap);
            } 
        }
    }
    
    protected override void handleBeforeDelete(Map<Id, SObject> oldMap) {
        AccountRecordTypeHandler handler = null;
        splitDataByRecordType(oldMap, null);        
        for(String recordTypeId : accountRecordTypeHandlerMap.keySet()) {
            handler = accountRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.accountOldMap.isEmpty()) {
                handler.recordTypeOperation.handleBeforeDelete(handler.accountOldMap);
            }
        }
    }
    
    protected override void handleAfterInsert(Map<Id, SObject> newMap) {
        AccountRecordTypeHandler handler = null;
        splitDataByRecordType(null, newMap);        
        for(String recordTypeId : accountRecordTypeHandlerMap.keySet()) {
            handler = accountRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.accountNewMap.isEmpty()) {
                handler.recordTypeOperation.handleAfterInsert(handler.accountNewMap);
            }
        }
    }  
    
    protected override void handleAfterUpdate(Map<Id,sObject> oldMap,Map<Id,sObject> newMap){
        AccountRecordTypeHandler handler = null;
        splitDataByRecordType(oldMap,newMap);
        for(String recordTypeId : accountRecordTypeHandlerMap.keySet()){
            handler = accountRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.accountNewMap.isEmpty()){
                handler.recordTypeOperation.handleAfterUpdate(handler.accountOldMap,handler.accountNewMap);
            }
        }
    }
    
    protected override void handleAfterDelete(Map<Id, SObject> oldMap) {
        AccountRecordTypeHandler handler = null;
        splitDataByRecordType(oldMap, null);
        for(String recordTypeId : accountRecordTypeHandlerMap.keySet()) {
            handler = accountRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.accountOldMap.isEmpty()) {
                handler.recordTypeOperation.handleAfterDelete(handler.accountOldMap);
            }
        }
    }
    
    protected override void handleAfterUndelete(Map<Id, SObject> newMap) {
        AccountRecordTypeHandler handler = null;
        splitDataByRecordType(null, newMap);
        for(String recordTypeId : accountRecordTypeHandlerMap.keySet()) {
            handler = accountRecordTypeHandlerMap.get(recordTypeId);
            if(!handler.accountNewMap.isEmpty()) {
                handler.recordTypeOperation.handleAfterUndelete(handler.accountNewMap);
            }
        }
    }
}