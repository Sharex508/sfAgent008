public class ContactTriggerHandlerNATT extends ContactTriggerHandlerAbstract {
    
    protected override void handleAfterInsert(Map<Id,SObject> trgNewMap) {        
        setAccountDealerPrincipal(trgNewMap.values(), null);
        setContactCounts(trgNewMap.values(), null);
        //SyncSobject.syncSobject(trgNewMap.values()); //DS to sync NAAT and TAVANT org - Ramkumar Murugesan 20th Jan 2023
    }
    
    protected override void handleAfterUpdate(Map<Id,SObject> trgOldMap, Map<Id,SObject> trgNewMap) {        
        setAccountDealerPrincipal(trgNewMap.values(), trgOldMap);
        setContactCounts(trgNewMap.values(), trgOldMap);
        
        
        //SyncSobject.syncSobject(trgNewMap.values()); //DS to sync NAAT and TAVANT org - Ramkumar Murugesan 20th Jan 2023
    }
    
    protected override void handleBeforeDelete(Map<Id,SObject> trgOldMap) {   
        validateDelete((Map<Id,Contact>)trgOldMap);
    }
    
    protected override void handleAfterDelete(Map<Id,SObject> trgOldMap) {   
        setContactCounts(trgOldMap.values(), null);
        if(!ContactDeleteCallout.firstcall){
            ContactDeleteCallout.firstcall = True;
            ContactDeleteCallout.contactDelete(trgOldMap.values()); // DS to sync deleted contacts with TAVANT org
        }
    }
    
    protected override void handleAfterUndelete(Map<Id,SObject> trgNewMap) {   
        setContactCounts(trgNewMap.values(), null);
    }
    
    protected override void handleBeforeInsert(List<SObject> newRecordsList) {
        setContactAccount(newRecordsList); //Update NATT_AccountActiveContact__c, NATT_AccountInactiveContact__c
    }
    
    protected override void handleBeforeUpdate(Map<Id,SObject> trgOldMap, Map<Id,SObject> trgNewMap) {        
        setContactAccount(trgNewMap.values()); //Update NATT_AccountActiveContact__c, NATT_AccountInactiveContact__c
    }
    
    private static void validateDelete(Map<Id,Contact> oldMap){
        User u = [SELECT Id, Profile.Name FROM User where Id=:UserInfo.getUserId()];
        
        for(Contact c : oldMap.values()){
            if(u.Profile.Name=='NATT Field Staff' || u.Profile.Name=='NATT Account Super User'){
                if(c.NATT_Record_Type_Developer_Name__c=='NATT_Direct_Sell_Internal' && u.Profile.Name=='NATT Field Staff'){
                    c.addError('You are not allowed to delete this contact.');
                }
                if(c.NATT_Account_Record_Type_Developer_Name__c=='NATT_Group_Ownership' && (u.Profile.Name=='NATT Field Staff'||u.Profile.Name=='NATT Account Super User')){
                    c.addError('You are not allowed to delete this contact.');
                }
            }
            if(u.Profile.Name=='NATT Dealer Master User' && (c.NATT_Key_Business_Role__c=='Principal'||c.NATT_Key_Business_Role__c=='Co-Principal'||c.NATT_Key_Business_Role__c=='Corporate Officer')){
                c.addError('You are not allowed to delete this contact.');
            }
        }
    }
    
    // Update the Account "Dealer Principal" lookup with the "Principal" contact 
    private static void setAccountDealerPrincipal(List<SObject> trgNew,  Map<Id,SObject> oldMap) {
        final String PRINCIPAL = 'Principal';         
        Map<Id,Set<Id>> accountToContactIdMap = new Map<Id,Set<Id>>();        
        List<Contact> nattConList = new List<Contact>();
        Set<Id> removedPrincipalIdSet = new Set<Id>();
        
        for (SObject contSobj : trgNew) {
            Contact cont = (Contact) contSobj;
            if (oldMap != null) {
                Contact oldContact =  (Contact) oldMap.get(cont.Id);                
                if ((oldContact.NATT_Key_Business_Role__c==PRINCIPAL||cont.NATT_Key_Business_Role__c==PRINCIPAL) && oldContact.NATT_Key_Business_Role__c!=cont.NATT_Key_Business_Role__c) {
                    if (!accountToContactIdMap.containsKey(cont.AccountId)) {
                        accountToContactIdMap.put(cont.AccountId,new Set<Id>());
                    }
                    
                    if (cont.NATT_Key_Business_Role__c!=PRINCIPAL && oldContact.NATT_Key_Business_Role__c==PRINCIPAL) {
                        removedPrincipalIdSet.add(cont.Id);
                    }
                    
                    accountToContactIdMap.get(cont.AccountId).add(cont.Id);   
                    nattConList.add(cont);
                }
            } else if (cont.NATT_Key_Business_Role__c==PRINCIPAL) {
                if (!accountToContactIdMap.containsKey(cont.AccountId)) {
                    accountToContactIdMap.put(cont.AccountId,new Set<Id>());
                }
                
                accountToContactIdMap.get(cont.AccountId).add(cont.Id);
                nattConList.add(cont);
            }
        }
        
        if (!accountToContactIdMap.isEmpty()) {
            // Check if a "principal" contact exists related to this Account
            Map<Id,List<Contact>> contactPrincipalMap = new Map<Id,List<Contact>>();
            for(Contact c : [SELECT Id, Name, AccountId,Account.Name FROM Contact WHERE NATT_Key_Business_Role__c = :PRINCIPAL AND AccountId IN :accountToContactIdMap.keySet() AND Id not in :removedPrincipalIdSet]){
                if(!contactPrincipalMap.containsKey(c.AccountId)){
                    contactPrincipalMap.put(c.AccountId,new List<Contact>());
                }
                contactPrincipalMap.get(c.AccountId).add(c);
            }
            Map<Id,Account> actMap = new Map<Id,Account>();
            for (Contact cont : nattConList) {
                if (contactPrincipalMap.containsKey(cont.AccountId)){
                    integer listSize = contactPrincipalMap.get(cont.AccountId).size();
                    if(listSize>=2) {
                        cont.addError('The account ' + contactPrincipalMap.get(cont.AccountId).get(0).Account.Name + ' already has as principal selected.');
                    } else if(listSize==1){
                        actMap.put(cont.AccountId, new Account(Id=cont.AccountId, NATT_Dealer_Principal__c=cont.Id));                        
                    }else if(listSize==0){
                        actMap.put(cont.AccountId, new Account(Id=cont.AccountId, NATT_Dealer_Principal__c=null));
                    }
                }else if(removedPrincipalIdSet.contains(cont.Id)){
                    actMap.put(cont.AccountId,new Account(Id=cont.AccountId,NATT_Dealer_Principal__c=null));
                }
            }
            
            // Update the Account and set the "Dealer Principal" lookup with the current Contact
            if (!actMap.isEmpty()){
                update actMap.values();
            }
        }
    }
    
    private Static void setContactCounts(List<SObject> trgNew,  Map<Id,SObject> oldMap){
        Set<Id> accountIdSet = new Set<Id>();
        list<account> lstAcc = new list<Account>();
        Id inActiveRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NATT_Inactive_Contact').getRecordTypeId();
        for (SObject contSobj : trgNew) {
            Contact cont = (Contact) contSobj;
             if (oldMap != null) {
                Contact oldContact = (Contact) oldMap.get(cont.Id); 
                if( oldContact.NATT_Refrigeration_Technician__c != cont.NATT_Refrigeration_Technician__c ||
                   (cont.NATT_Key_Business_Role__c != oldContact.NATT_Key_Business_Role__c) || (cont.RecordTypeId !=oldContact.RecordTypeId)){
                       accountIdSet.add(cont.AccountId);
                   }
            } else if (cont.NATT_Refrigeration_Technician__c || cont.NATT_Key_Business_Role__c=='Unit Sales Person' || cont.NATT_Key_Business_Role__c=='Sales Manager' || 
                       cont.NATT_Key_Business_Role__c=='Parts Sales Person'  || cont.NATT_Key_Business_Role__c=='Parts Manager') {
                           accountIdSet.add(cont.AccountId);
                       }
          
        }
       
        if (!accountIdSet.isEmpty()) {
            
            
            List<Account> aList = new List<Account>([SELECT Id,(SELECT Id,NATT_Refrigeration_Technician__c,NATT_Key_Business_Role__c,RecordType.DeveloperName
                                                                FROM Contacts 
                                                                WHERE RecordTypeId !=: inActiveRecordTypeId AND (NATT_Refrigeration_Technician__c=true OR NATT_Key_Business_Role__c in ('Unit Sales Person','Sales Manager','Parts Sales Person','Parts Manager'))) 
                                                     FROM Account WHERE Id in :accountIdSet]);
           
            integer refTech, unitSales, partSales;
            for(Account a : aList) {
                refTech=0;
                unitSales=0;
                partSales=0;
                for(Contact c : a.Contacts){
                    
                    if(c.NATT_Refrigeration_Technician__c ){
                        refTech++;
                    }
                    if(c.NATT_Key_Business_Role__c=='Unit Sales Person' || c.NATT_Key_Business_Role__c=='Sales Manager' ){
                        unitSales++;
                       
                    }
                    if(c.NATT_Key_Business_Role__c=='Parts Sales Person' || c.NATT_Key_Business_Role__c=='Parts Manager' ){
                        partSales++;
                    }
                
              }
                    
                a.NATT_Number_of_Refrigeration_Techs__c=refTech;
                a.NATT_Number_of_Parts_People__c=partSales;
                a.NATT_Number_of_Sales_People__c=unitSales;
                
            }
            
            update aList;
        }
    }
    
    private static void setContactAccount(List<SObject> newRecordsList){ 
        for(SObject contSobj : newRecordsList){
            Contact cont = (Contact) contSobj;
            
            if(cont.AccountId <> null){
                if(cont.RecordTypeId <> null){
                    if(cont.RecordTypeId != Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NATT_Inactive_Contact').getRecordTypeId()){
                        cont.NATT_AccountActiveContact__c = cont.AccountId;
                        cont.NATT_AccountInactiveContact__c = null;
                    }
                } else {
                    cont.NATT_AccountInactiveContact__c = cont.AccountId;
                }
            }
        }
    }
}