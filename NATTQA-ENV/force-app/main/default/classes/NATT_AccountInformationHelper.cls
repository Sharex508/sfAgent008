public with sharing class NATT_AccountInformationHelper {


    /*Query for Effective Acct for Acct Details, Addresses, Carts
    @AuraEnabled(cacheable=true)
    public static List <Account> grabEffectiveAccounts(String acctId){
        List <Account> accountList = [SELECT Name, NATT_Parts_Account__c, NATT_JDE_Parts_Bill_To_Code__c, NATT_Division__c, NATT_Primary_Location_Type__c, NATT_Dealer_Principal__c, NATT_Physical_Address__c, ShippingAddress, NATT_Dealer__c FROM Account WHERE Id = :acctId];
        return accountList;
    }*/

    //Query used to grab Effective Acct for Acct Details
    @AuraEnabled(cacheable=true)
    public static Account grabEffectiveAccount(String acctId){
        Account a = [SELECT Name, NATT_Parts_Account__c, NATT_JDE_Parts_Bill_To_Code__c, NATT_Division__c, NATT_Primary_Location_Type__c, NATT_Dealer_Principal__c, NATT_Physical_Address__c, ShippingAddress, NATT_Dealer__c FROM Account WHERE Id = :acctId];
        return a;
    }

    // //Old method used for grabbing Accounts via User instead of Effective Acct Id
    // @AuraEnabled(cacheable=true)
    // public static List <Account> grabAccounts(String userId){
    //     // List <Account> accountList2 = [SELECT Name, NATT_Parts_Account__c, NATT_JDE_Parts_Bill_To_Code__c, NATT_Division__c, NATT_Primary_Location_Type__c, NATT_Dealer_Principal__c, NATT_Physical_Address__c, ShippingAddress, NATT_Dealer__c FROM Account WHERE Id IN :acctIds];
    //     User userRecord = [SELECT ContactId FROM User WHERE Id = :userId];
    //     Contact userContact = [SELECT AccountId FROM Contact WHERE Id = :userRecord.ContactId];
    //     List <Account> accountList = [SELECT Name, NATT_Parts_Account__c, NATT_JDE_Parts_Bill_To_Code__c, NATT_Division__c, NATT_Primary_Location_Type__c, NATT_Dealer_Principal__c, NATT_Physical_Address__c, ShippingAddress, NATT_Dealer__c FROM Account WHERE Id = :userContact.AccountId];
    //     return accountList;
    // }

    @AuraEnabled
    public static List <ContactPointAddress> grabAddresses(String effAccountId){
        // List <Account> acctList = grabAccounts(userId);
        //SYstem.debug('Effective ACct Id: ' + effAccountId);
        //Account a  = grabEffectiveAccount(effAccountId);        
        List <ContactPointAddress> contactPointAddresses = [SELECT Id, Name, ParentId, Address, street, city, state, postalcode, country,NATT_Address__c FROM ContactPointAddress WHERE (NATT_Address__c = null) AND AddressType = 'Shipping' AND ParentId =:effAccountId];
        System.debug('contact point Addresses: ' + contactPointAddresses);
        return contactPointAddresses;
    }

    @AuraEnabled
    public static List <ContactPointAddress> grabJdeAddresses(String effAccountId){
        // List <Account> acctList = grabAccounts(userId);
        //List <Account> acctList = grabEffectiveAccount(userId);
        //List <Id> acctIds = new List <Id> ();
        //for (Account acct : acctList){
        //    acctIds.add(acct.Id);
        //}
        List <ContactPointAddress> contactPointAddresses = [SELECT Id, Name, ParentId, Address, street, city, state, postalcode, country,NATT_Address__c FROM ContactPointAddress WHERE (NATT_Address__c != null) AND AddressType = 'Shipping' AND ParentId =:effAccountId];
        return contactPointAddresses;
    }

    @AuraEnabled    
    public static boolean updateAddresses(List <ContactPointAddress> updatedAccountList) {    
        for (ContactPointAddress cpa : updatedAccountList){
            System.debug('ID VALUE : ' + cpa.id);
        }
        try {  
            update updatedAccountList;  
            return true;   
        } catch(Exception e) {  
            return false;      
        }   
    }  
    
    @AuraEnabled(cacheable=true)
    public static Account grabAccountDetails(String acctId){
        List<Account> accountList = [SELECT Name, NATT_Parts_Account__c, NATT_JDE_Parts_Bill_To_Code__c, NATT_Division__c, NATT_Primary_Location_Type__c, 
                                    NATT_Dealer_Principal__c, NATT_Physical_Address__c, NATT_Mailing_Address__c,NATT_Dealer_Principal__r.Email
                                    FROM Account  WHERE Id =:acctId];
        return accountList.isEmpty()? new Account():accountList.get(0);
    }

    @AuraEnabled
    public static void deleteAddress(ContactPointAddress conPointAddress){
        NATT_DeleteContactPointAddresses.deleteContactPointAddress(conPointAddress);
    } 

}