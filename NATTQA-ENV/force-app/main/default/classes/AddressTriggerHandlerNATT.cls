public class AddressTriggerHandlerNATT extends AddressTriggerHandlerAbstract {

    protected override void handleBeforeInsert(List<SObject> trgNew) {
        Map<String,NATT_Address__c> actToAddMap = new Map<String,NATT_Address__c>(); 
        Set<Id> actIdSet = new Set<Id>();
        
        for (SObject addr : trgNew) {
            NATT_Address__c add = (NATT_Address__c) addr;
            formatName(add);
            if (NATT_Constants.NATT_ADDRESS_TYPE_TRIGGER.contains(add.NATT_Type__c)) {
                if (!actToAddMap.containsKey(add.NATT_Account__c+add.NATT_Type__c)) {
                    actToAddMap.put(add.NATT_Account__c+add.NATT_Type__c,add);
                    actIdSet.add(add.NATT_Account__c);
                } else {
                    add.addError('There are two '+add.NATT_Type__c+' addresses being added.');
                }
            }
        }
        if (!actToAddMap.isEmpty()) {
            checkDuplicate(actToAddMap, actIdSet);
        }
    }
	
	protected override void handleBeforeUpdate(Map<Id,SObject> trgOldMap, Map<Id,SObject> trgNewMap) {
        Map<String,NATT_Address__c> actToAddMap = new Map<String,NATT_Address__c>();        
        Set<Id> actIdSet = new Set<Id>();

        for (SObject addr : trgNewMap.values()) {
            NATT_Address__c add = (NATT_Address__c) addr;
            NATT_Address__c oldAdd = (NATT_Address__c) trgOldMap.get(add.Id);

            formatName(add);
            if (NATT_Constants.NATT_ADDRESS_TYPE_TRIGGER.contains(add.NATT_Type__c) && oldAdd.NATT_Type__c!=add.NATT_Type__c) {
                if (!actToAddMap.containsKey(add.NATT_Account__c+add.NATT_Type__c)) {
                    actToAddMap.put(add.NATT_Account__c+add.NATT_Type__c,add);
                    actIdSet.add(add.NATT_Account__c);
                } else {
                    add.addError('There are two '+add.NATT_Type__c+' addresses being added.');
                }
            }
        }

        if(!actToAddMap.isEmpty()){
            checkDuplicate(actToAddMap,actIdSet);
        }
    }
    
    protected override void handleBeforeDelete(Map<Id,SObject> trgOldMap) {        
        validateDelete((Map<Id,NATT_Address__c>)trgOldMap);
    }
    
    protected override void handleAfterInsert(Map<Id, SObject> trgNewMap) {
        Map<Id,Account> actUpdateMap = new Map<Id,Account>();

        for (SObject addr : trgNewMap.values()) {
            NATT_Address__c add = (NATT_Address__c) addr;
            if (NATT_Constants.NATT_ADDRESS_TYPE_TRIGGER.contains(add.NATT_Type__c)) {
                if (!actUpdateMap.containsKey(add.NATT_Account__c)){
                    actUpdateMap.put(add.NATT_Account__c,new Account(Id=add.NATT_Account__c));
                }

                if (add.NATT_Type__c==NATT_Constants.NATT_ADDRESS_TYPE_HEADQUARTERS) {
                    actUpdateMap.get(add.NATT_Account__c).NATT_Address_Headquarters__c=add.Id;
                } else if(add.NATT_Type__c==NATT_Constants.NATT_ADDRESS_TYPE_PHYSICAL) {                    
                    actUpdateMap.get(add.NATT_Account__c).NATT_Address_Physical__c=add.Id;
                } else if(add.NATT_Type__c==NATT_Constants.NATT_ADDRESS_TYPE_MAILING) {
                    actUpdateMap.get(add.NATT_Account__c).NATT_Address_Mailing__c=add.Id;
                }
            }
        }

        if (!actUpdateMap.isEmpty()) {
            update actUpdateMap.values();
        }
    }    

    protected override void handleAfterUpdate(Map<Id,SObject> trgOldMap, Map<Id,SObject> trgNewMap) {
        Map<Id,Account> actUpdateMap = new Map<Id,Account>();        

        for (SObject addr : trgNewMap.values()) {
            NATT_Address__c add = (NATT_Address__c) addr;
            NATT_Address__c oldAdd = (NATT_Address__c) trgOldMap.get(add.Id);

            if (NATT_Constants.NATT_ADDRESS_TYPE_TRIGGER.contains(add.NATT_Type__c)) {
                if (!actUpdateMap.containsKey(add.NATT_Account__c)) {
                    actUpdateMap.put(add.NATT_Account__c,new Account(Id=add.NATT_Account__c));
                }

                if (add.NATT_Type__c==NATT_Constants.NATT_ADDRESS_TYPE_HEADQUARTERS) {
                    actUpdateMap.get(add.NATT_Account__c).NATT_Address_Headquarters__c=add.Id;
                } else if(add.NATT_Type__c==NATT_Constants.NATT_ADDRESS_TYPE_PHYSICAL) {                    
                    actUpdateMap.get(add.NATT_Account__c).NATT_Address_Physical__c=add.Id;
                } else if(add.NATT_Type__c==NATT_Constants.NATT_ADDRESS_TYPE_MAILING) {
                    actUpdateMap.get(add.NATT_Account__c).NATT_Address_Mailing__c=add.Id;
                }
                if(NATT_Constants.NATT_ADDRESS_TYPE_TRIGGER.contains(oldAdd.NATT_Type__c) && add.NATT_Type__c!=oldAdd.NATT_Type__c){
                    if (oldAdd.NATT_Type__c==NATT_Constants.NATT_ADDRESS_TYPE_HEADQUARTERS) {
                        actUpdateMap.get(add.NATT_Account__c).NATT_Address_Headquarters__c=null;
                    } else if(oldAdd.NATT_Type__c==NATT_Constants.NATT_ADDRESS_TYPE_PHYSICAL) {                    
                        actUpdateMap.get(add.NATT_Account__c).NATT_Address_Physical__c=null;
                    } else if(oldAdd.NATT_Type__c==NATT_Constants.NATT_ADDRESS_TYPE_MAILING) {
                        actUpdateMap.get(add.NATT_Account__c).NATT_Address_Mailing__c=null;
                    }
                }
            } else if (NATT_Constants.NATT_ADDRESS_TYPE_TRIGGER.contains(oldAdd.NATT_Type__c)) {
                if (!actUpdateMap.containsKey(add.NATT_Account__c)) {
                    actUpdateMap.put(add.NATT_Account__c,new Account(Id=add.NATT_Account__c));
                }

                if (oldAdd.NATT_Type__c==NATT_Constants.NATT_ADDRESS_TYPE_HEADQUARTERS) {
                    actUpdateMap.get(add.NATT_Account__c).NATT_Address_Headquarters__c=null;
                } else if(oldAdd.NATT_Type__c==NATT_Constants.NATT_ADDRESS_TYPE_PHYSICAL) {                    
                    actUpdateMap.get(add.NATT_Account__c).NATT_Address_Physical__c=null;
                } else if(oldAdd.NATT_Type__c==NATT_Constants.NATT_ADDRESS_TYPE_MAILING) {
                    actUpdateMap.get(add.NATT_Account__c).NATT_Address_Mailing__c=null;
                }
            }
        }

        if (!actUpdateMap.isEmpty()) {
            update actUpdateMap.values();
        }
    }

    private static void validateDelete(Map<Id,NATT_Address__c> oldMap){
        User u = [SELECT Id, Profile.Name FROM User where Id=:UserInfo.getUserId()];
        if(u.Profile.Name=='NATT Account Super User'){
            for(NATT_Address__c addr : oldMap.values()){
                if(addr.NATT_Type__c=='Billing'||addr.NATT_Type__c=='Mailing'||addr.NATT_Type__c=='Headquarters'||addr.NATT_Type__c=='Units Ship To'||addr.NATT_Type__c=='Parts Ship To'){
                    addr.addError('You are not allowed to delete this address.');
                }
            }
        }
    }
    
    private static void checkDuplicate(Map<String,NATT_Address__c> actToAddMap,Set<Id> actIdSet){
        //check to see if there are any existing HQ records
        for (NATT_Address__c add : [SELECT Id,Name,NATT_Account__c,NATT_Type__c FROM NATT_Address__c WHERE NATT_Type__c in :NATT_Constants.NATT_ADDRESS_TYPE_TRIGGER AND NATT_Account__c in :actIdSet]) {
            if (actToAddMap.containsKey(add.NATT_Account__c+add.NATT_Type__c)) {
                actToAddMap.get(add.NATT_Account__c+add.NATT_Type__c).addError('There is an existing '+add.NATT_Type__c+' address: '+ add.Name + ' ('+add.Id+')');
            }
        }      
    }

    private static void formatName(NATT_Address__c add) {
        String type = String.isNotBlank(add.NATT_Type__c) ? add.NATT_Type__c : '';
        String jdeAlpha = String.isNotBlank(add.NATT_JDE_Alpha_Name__c) ? ' - ' + add.NATT_JDE_Alpha_Name__c : '';
        String city = String.isNotBlank(add.NATT_City__c) ? ' - ' + add.NATT_City__c : '';
        String stateProvince = String.isNotBlank(add.NATT_State_Province__c) ? ' - ' + add.NATT_State_Province__c : '';

        String name = type + jdeAlpha + city + stateProvince;
        
        if (String.isBlank(add.NATT_City__c) || String.isBlank(add.NATT_State_Province__c)) {
            name = name.remove(', ').remove('null');
        }        
        
        add.Name = name.length()>80 ? name.substring(0,76) + '...' : name;
    }

}