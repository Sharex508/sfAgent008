public without sharing class UserTriggerHandler extends TriggerHandlerVirtual{
    static Map<String,UserProfileHandler> userProfileHandlerMap = new Map<String,UserProfileHandler>();
    
    /*Map which defines record type to handler class
	* user trigger executes and calls mapped handler class*/
    private static Map<String,List<String>> userProfileClassMap = new Map<String,List<String>>{
        'UserTriggerHandlerNATT' => NATT_CONSTANTS.NATT_USER_PROFILE_LIST
    };
        
    public UserTriggerHandler(){
       super(User.SobjectType);
    }
    
    {
        UserProfileHandler handler = null;
        Map<String,Id> profileInfoMap = new Map<String,Id>();
        for(Profile p : [SELECT Id,Name FROM Profile]){
            profileInfoMap.put(p.Name,p.Id);
        }
        
        userProfileClassMap.get('UserTriggerHandlerNATT').addAll(new List<String>{'CTM Accounts Read Only','CTM Customer Master Responsible','CTM Full Access Community','CTM General Manager','CTM IT Support','CTM Manager','CTM Sales Director','CTM Sales User','CTM Support User','CTBR Customer Master Responsible', 'CTBR Full Access Community', 'CTBR General Manager', 'CTBR IT Support', 'CTBR Manager', 'CTBR Sales Manager', 'CTBR Sales User', 'CTBR Support User'});
            
        for(String className : userProfileClassMap.keySet()){
            handler = new userProfileHandler();
            handler.profileOperation = (userTriggerHandlerAbstract)Type.forName(className).newInstance();
            for(String profileName : userProfileClassMap.get(className)){
                userProfileHandlerMap.put(profileInfoMap.get(profileName),handler);
            }
        }
    }
    private void splitDataByProfile(Object oldObject,Object newObject){
        User userRecord = null;
        userProfileHandler rtHandler = null;
        List<sObject> soList = Trigger.isBefore && Trigger.isInsert ? (List<sObject>)newObject : 
        Trigger.isDelete ? ((Map<Id,sObject>) oldObject).values() : 
        ((Map<Id,sObject>)newObject).values();
        Map<Id,sObject> oldMap = oldObject !=null ? (Map<Id,sObject>)oldObject : new Map<Id,sObject>();        
        
        for(sObject userObject : soList){
            userRecord = (User)userObject;
            if(userProfileHandlerMap.containsKey(userRecord.ProfileId)){
                rtHandler = userProfileHandlerMap.get(userRecord.ProfileId);
                if(trigger.isBefore && trigger.isInsert){
                    rtHandler.userNewList.add(userRecord);
                }else if(trigger.isDelete){
                    rtHandler.userOldMap.put(userRecord.Id,userRecord);
                }else{
                    rtHandler.userNewMap.put(userRecord.Id,userRecord);
                    rtHandler.userOldMap.put(userRecord.Id,(User)oldMap.get(userRecord.Id));
                }                
            }
        }
    }
    
    class UserProfileHandler{
        UserTriggerHandlerAbstract profileOperation {get;set;}
        Map<Id,User> userOldMap {get;set;}
        Map<Id,User> userNewMap {get;set;}
        List<User> userNewList {get;set;}
        UserProfileHandler() {
            userNewList = new List<User>();
            userNewMap = new Map<Id,User>();
            userOldMap = new Map<Id,User>();
        }
    }
    
    protected override void handleBeforeInsert(List<SObject> newList) {
        UserProfileHandler handler = null;
        splitDataByProfile(null, newList);
        for(String profileId : UserProfileHandlerMap.keySet()) {
            handler = UserProfileHandlerMap.get(profileId);
            if(!handler.userNewList.isEmpty()) {
                handler.profileOperation.handleBeforeInsert(handler.userNewList);
            }
        }
    }
    
    protected override void handleBeforeUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
        UserProfileHandler handler = null;
        splitDataByProfile(oldMap, newMap);        
        
        for(String profileId : UserProfileHandlerMap.keySet()) {
            handler = UserProfileHandlerMap.get(profileId);
            if(!handler.userNewMap.isEmpty()) {
                handler.profileOperation.handleBeforeUpdate(handler.userOldMap, handler.userNewMap);
            } 
        }
    }
    
    protected override void handleBeforeDelete(Map<Id, SObject> oldMap) {
        UserProfileHandler handler = null;
        splitDataByProfile(oldMap, null);        
        for(String profileId : UserProfileHandlerMap.keySet()) {
            handler = userProfileHandlerMap.get(profileId);
            if(!handler.userOldMap.isEmpty()) {
                handler.profileOperation.handleBeforeDelete(handler.userOldMap);
            }
        }
    }
    
    protected override void handleAfterInsert(Map<Id, SObject> newMap) {
        UserProfileHandler handler = null;
        splitDataByProfile(null, newMap);        
        for(String profileId : userProfileHandlerMap.keySet()) {
            handler = userProfileHandlerMap.get(profileId);
            if(!handler.userNewMap.isEmpty()) {
                handler.profileOperation.handleAfterInsert(handler.userNewMap);
            }
        }
    }  
    
    protected override void handleAfterUpdate(Map<Id,sObject> oldMap,Map<Id,sObject> newMap){
        UserProfileHandler handler = null;
        splitDataByProfile(oldMap,newMap);
        for(String profileId : userProfileHandlerMap.keySet()){            
            handler = userProfileHandlerMap.get(profileId);
            if(!handler.userNewMap.isEmpty()){
                handler.profileOperation.handleAfterUpdate(handler.userOldMap,handler.userNewMap);
            }
        }
    }
    
    protected override void handleAfterDelete(Map<Id, SObject> oldMap) {
        UserProfileHandler handler = null;
        splitDataByProfile(oldMap, null);
        for(String profileId : userProfileHandlerMap.keySet()) {
            handler = userProfileHandlerMap.get(profileId);
            if(!handler.userOldMap.isEmpty()) {
                handler.profileOperation.handleAfterDelete(handler.userOldMap);
            }
        }
    }
    
    protected override void handleAfterUndelete(Map<Id, SObject> newMap) {
        UserProfileHandler handler = null;
        splitDataByProfile(null, newMap);
        for(String profileId : userProfileHandlerMap.keySet()) {
            handler = userProfileHandlerMap.get(profileId);
            if(!handler.userNewMap.isEmpty()) {
                handler.profileOperation.handleAfterUndelete(handler.userNewMap);
            }
        }
    }
}