public class UserTriggerHandlerNATT extends UserTriggerHandlerAbstract{
    Map<String,Id> nameToGroupIdMap {
        get{
            if(nameToGroupIdMap==null){
                nameToGroupIdMap = new Map<String,Id>();
                for(Group g : [select Id,DeveloperName FROM Group where DeveloperName in ('NATT_Associate','NATT_Customer','NATT_Dealer','NATT_Dealer_Principal','NATT_Internal','CTM_Internal','CTM_Dealer_Region_1','CTM_Dealer_Region_2','CTM_Dealer_Region_3','CTBR_Dealer','CTBR_Internal')]){
                    nameToGroupIdMap.put(g.DeveloperName,g.Id);
                }                
            }
            return nameToGroupIdMap;
        }
        set;}    
    
    
    public override void handleAfterInsert(Map<Id,SObject> trgNewMap){
        Map<Id,User> newMap = (Map<Id,User>)trgNewMap;        
        setNattGroupAccess(null,newMap); 
    }
    public override void handleAfterUpdate(Map<Id,Sobject> trgOldMap, Map<Id,SObject> trgNewMap){
        Map<Id,User> newMap = (Map<Id,User>)trgNewMap;
        Map<Id,User> oldMap = (Map<Id,User>)trgOldMap;
        setNattGroupAccess(oldMap,newMap);        
    }
    private void setNattGroupAccess(Map<Id,User> oldMap, Map<Id,User> newMap){        
        Map<Id,Set<String>> removalMap = new Map<Id,Set<String>>();
        User oldU;
        boolean isInsert = (oldMap==null);
        
        List<GroupMember> gmList = new List<GroupMember>();
        for(User u : newMap.values()){            
            if(oldMap!=null){
            	oldU = oldMap.get(u.Id);
            }
            if((isInsert && u.Natt_Associate__c) || (!isInsert && u.NATT_Associate__c != oldU.NATT_Associate__c)){
                addRemove(u.NATT_Associate__c,removalMap,u.Id,'NATT_Associate',gmList,nameToGroupIdMap);
            }            
            if((isInsert && u.Natt_Customer__c) || (!isInsert && u.NATT_Customer__c != oldU.NATT_Customer__c)){
                addRemove(u.NATT_Customer__c,removalMap,u.Id,'NATT_Customer',gmList,nameToGroupIdMap);
            }
            if((isInsert && u.Natt_Dealer__c) || (!isInsert && u.NATT_Dealer__c != oldU.NATT_Dealer__c)){
                addRemove(u.NATT_Dealer__c,removalMap,u.Id,'NATT_Dealer',gmList,nameToGroupIdMap);
            }
            if((isInsert && u.Natt_Dealer_Principal__c) || (!isInsert && u.NATT_Dealer_Principal__c != oldU.NATT_Dealer_Principal__c)){
                addRemove(u.NATT_Dealer_Principal__c,removalMap,u.Id,'NATT_Dealer_Principal',gmList,nameToGroupIdMap);                
            }
            if((isInsert && u.Natt_Internal__c) || (!isInsert && u.NATT_Internal__c != oldU.NATT_Internal__c)){
                addRemove(u.NATT_Internal__c,removalMap,u.Id,'NATT_Internal',gmList,nameToGroupIdMap);
            }
            if((isInsert && u.CTM_Internal__c) || (!isInsert && u.CTM_Internal__c != oldU.CTM_Internal__c)){
                addRemove(u.CTM_Internal__c,removalMap,u.Id,'CTM_Internal',gmList,nameToGroupIdMap);
            }
            if((isInsert && u.CTM_Dealer_Region_1__c) || (!isInsert && u.CTM_Dealer_Region_1__c != oldU.CTM_Dealer_Region_1__c)){
                addRemove(u.CTM_Dealer_Region_1__c,removalMap,u.Id,'CTM_Dealer_Region_1',gmList,nameToGroupIdMap);
            }
            if((isInsert && u.CTM_Dealer_Region_2__c) || (!isInsert && u.CTM_Dealer_Region_2__c != oldU.CTM_Dealer_Region_2__c)){
                addRemove(u.CTM_Dealer_Region_2__c,removalMap,u.Id,'CTM_Dealer_Region_2',gmList,nameToGroupIdMap);
            }
            if((isInsert && u.CTM_Dealer_Region_3__c) || (!isInsert && u.CTM_Dealer_Region_3__c != oldU.CTM_Dealer_Region_3__c)){
                addRemove(u.CTM_Dealer_Region_3__c,removalMap,u.Id,'CTM_Dealer_Region_3',gmList,nameToGroupIdMap);
            }
            if((isInsert && u.CTBR_Dealer__c) || (!isInsert && u.CTBR_Dealer__c != oldU.CTBR_Dealer__c)){
                addRemove(u.CTBR_Dealer__c,removalMap,u.Id,'CTBR_Dealer',gmList,nameToGroupIdMap);
            }
            if((isInsert && u.CTBR_Internal__c) || (!isInsert && u.CTBR_Internal__c != oldU.CTBR_Internal__c)){
                addRemove(u.CTBR_Internal__c,removalMap,u.Id,'CTBR_Internal',gmList,nameToGroupIdMap);
            }
        }
        if(!gmList.isEmpty()){
            insert gmList;
        }
        if(!removalMap.isEmpty()){
            List<GroupMember> gmDeleteList = new List<GroupMember>();
            for(GroupMember gm : [SELECT Id,Group.DeveloperName,UserOrGroupId FROM GroupMember WHERE UserOrGroupId in :removalMap.keySet()]){
                if(removalMap.containsKey(gm.UserOrGroupId) && removalMap.get(gm.UserOrGroupId).contains(gm.Group.DeveloperName)){
                    gmDeleteList.add(gm);
                }
            }
            if(!gmDeleteList.isEmpty()){
                delete gmDeleteList;
            }
        }
    }
    private void addRemove(boolean isAdd, Map<Id,Set<String>> removalMap,Id userId,String groupDevName,List<GroupMember> gmList,Map<String,Id> nameToGroupIdMap){
        if(isAdd){
            gmList.add(new GroupMember(GroupId=nameToGroupIdMap.get(groupDevName),UserOrGroupId=userId));
        }else{
            if(!removalMap.containsKey(userId)){
                removalMap.put(userId,new Set<String>());
            }
            removalMap.get(userId).add(groupDevName);
        }
    }
}