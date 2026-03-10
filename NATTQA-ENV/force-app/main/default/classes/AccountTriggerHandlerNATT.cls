public class AccountTriggerHandlerNATT extends AccountTriggerHandlerAbstract{
    
    protected override void handleBeforeDelete(Map<Id,SObject> trgOldMap) {        
        validateDelete((Map<Id,Account>)trgOldMap);
    }
    
    //protected override void handleBeforeUpdate(Map<Id,SObject> trgOldMap, Map<Id,SObject> trgNewMap) {        
        //checkUserAccess(trgNewMap.values()); //Prevent Partners Users w/ Inactive Contacts to Edit Accounts
    //}
    
/* Prevent Dealer Account Deletion if the user is
Account Super User, Field Staff, or All NATT community profiles
Prevent Group Account Deletion if the user is
Account Super User, Field Staff, or All Natt community profiles
Prevent Customer Account Deletion if the user is
Field Staff
Prevent Internal Account and Direct Sale Account Deletion if the user is
Field Staff or All Dealers*/
    
    private static void validateDelete(Map<Id,Account> oldMap){
        User u = [SELECT Id, Profile.Name FROM User where Id=:UserInfo.getUserId()];
        for(Account a : oldMap.values()){
            if(a.NATT_Status__c=='Pending'){
                continue;
            }
            if(((u.Profile.Name=='NATT Account Super User'||u.Profile.Name=='NATT Field Staff' || u.Profile.Name=='NATT Associate With Tavant Community'|| u.Profile.Name=='NATT Associate Without Tavant Community'|| u.Profile.Name=='NATT Full Access Community'
                 || u.Profile.Name=='NATT Parts and Service Community'|| u.Profile.Name=='NATT Parts Only Community'|| u.Profile.Name=='NATT Sales Only Community'|| u.Profile.Name=='NATT Technical Community'|| u.Profile.Name=='NATT Warranty Only Community') 
                && (a.NATT_Record_Type_Developer_Name__c=='Dealer' || a.NATT_Record_Type_Developer_Name__c=='NATT_Group_Ownership')) ||
               (u.Profile.Name=='NATT Field Staff' &&  a.NATT_Record_Type_Developer_Name__c=='Customer')||
               ((u.Profile.Name=='NATT Field Staff' || u.Profile.Name=='NATT Dealer Master User') &&(a.NATT_Record_Type_Developer_Name__c=='NATT_OEM'||a.NATT_Record_Type_Developer_Name__c=='Internal')) || (a.NATT_Status__c=='Active' || a.NATT_Status__c=='Terminated')){                
                   a.addError('You are not allowed to delete this account.');
               }            
        }        
    }
    
    /*private static void checkUserAccess(List<SObject> newList){
        User u = [SELECT ID, ContactId, Contact.NATT_Record_Type_Developer_Name__c FROM User WHERE ID =: UserInfo.getUserId()];
        if(u.ContactId == null){
            return;
        }
        
        for(SObject sObj : newList){
            if(u.Contact.NATT_Record_Type_Developer_Name__c == 'NATT_Inactive_Contact'){
                sObj.addError(Label.NATT_Inactive_Contact_Check_Access);                
            }
        }
    }*/
    
    //DS to sync NAAT and TAVANT org
    protected override void handleAfterInsert(Map<Id, SObject> newMap){
        //checkUserAccess(newMap.values()); //Prevent Partners Users w/ Inactive Contacts to Create Accounts
        SyncSobject.syncSobject(newMap.values());
    }
    
    //DS to sync NAAT and TAVANT org
    protected override void handleAfterUpdate(Map<Id,sObject> oldMap,Map<Id,sObject> newMap){
        SyncSobject.syncSobject(newMap.values());
    }
}