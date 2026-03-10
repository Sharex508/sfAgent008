/**
* @date 2022
* @description Test data factory. Should be used in every test class to generate data for testing.
*  Each object has function responsible for just creating given object,
*  and function which perform create and insert operation
* @group Testing util
*/

public without sharing class NAC_UserSignUp {
    @AuraEnabled
    public static userWrapper getAddressDetails(String userAccountNumber){        
        userWrapper userWrap = new userWrapper();
        Account selectedAcc=[SELECT Id,AccountNumber FROM Account where Id =:userAccountNumber Limit 1];
        system.debug('selectedAcc@@'+selectedAcc);
        userWrap.addressList = [SELECT Id, Street, City, State, PostalCode, Country, IsDefault, AddressType FROM ContactPointAddress WHERE Recordtype.Name='NAC' AND  ParentId =: selectedAcc.Id AND Status__c = 'Approved'];
        system.debug('addressList@@'+userWrap.addressList);
        return userWrap;
    }
    
    @AuraEnabled
    public static String getAccountNumberDetails(){
        String accName = '';
		User usrInfo = [SELECT Id, Contact.Account.Name FROM User WHERE Id =: UserInfo.getUserId()];
        if(String.isNotBlank(usrInfo.Contact.Account.Name)){
            accName = usrInfo.Contact.Account.Name;
        }
        return accName;
    }
    
    @AuraEnabled
    public static Boolean createContact(Map<Object, Object> contactData){
        System.debug('contactData--->'+contactData);
        Savepoint sp;
        sp = Database.setSavepoint();
        Boolean isContactCreated = false;
        try{
            // inserting contact
            // get Dealer RT
            Account parentAcc=[SELECT Id,Name,(Select Id from Contacts) from Account where Id=:(String)contactData.get('accountNumber')];
            Id naocapRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('NAOCAP End Customer').getRecordTypeId();
            Contact con= new Contact();                     
            con.FirstName =(String)contactData.get('contactFirstName');
            con.LastName =(String)contactData.get('contactLastName');
            con.Email=(String)contactData.get('email');
            con.Title=(String)contactData.get('jobTitle');
            con.Phone=(String)contactData.get('phoneNumber'); 
            con.AccountId=parentAcc.Id;
            con.NAC_Status__c ='Pending';
            con.NAC_Contact_Type__c =(String)contactData.get('contactType');
            con.recordtypeId = naocapRecordTypeId;
            insert con;           
            isContactCreated= true;             
            
        }catch(Exception e){
            Database.rollback(sp);
            isContactCreated = false;            
            system.debug('exception ' + e.getTypeName());
            system.debug('exception ' + e.getMessage());
            system.debug('exception ' + e.getStackTraceString());
        }
        
        return isContactCreated;
    }
    
    @AuraEnabled
    public static Boolean createAccount(Map<Object, Object> accountData){
        System.debug('accountData--->'+accountData);
        Savepoint sp;
        sp = Database.setSavepoint();
        Boolean isContactCreated = false;
        try{

            Id customerAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('NAOCAP Customer').getRecordTypeId();
            Id customerContactRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('NAOCAP End Customer').getRecordTypeId();
            
            // inserting account            
            Account ac = new Account();
            ac.Name=(String)accountData.get('legalCompanyName');
            ac.NAC_status__c ='Pending';      
            ac.recordtypeId=customerAccountRecordTypeId;            
            ac.Phone = (String)accountData.get('accountPhoneNumber');
            ac.WOD_2_Email__c = (String)accountData.get('accountEmailAddress');
            ac.Website = (String)accountData.get('accountWebpage');
            ac.BillingStreet = (String)accountData.get('accountBillingStreetAddress');
            ac.BillingCity = (String)accountData.get('accountBillingCity');
            ac.BillingState = (String)accountData.get('accountBillingState');
            ac.BillingPostalCode = (String)accountData.get('accountBillingZipCode');
            ac.BillingCountry = (String)accountData.get('accountBillingCountry');
            ac.ShippingStreet = (String)accountData.get('accountShippingStreetAddress');
            ac.ShippingCity = (String)accountData.get('accountShippingCity');
            ac.ShippingState = (String)accountData.get('accountShippingState');
            ac.ShippingPostalCode = (String)accountData.get('accountShippingZipCode');
            ac.ShippingCountry = (String)accountData.get('accountShippingCountry');
            
            insert ac;            
            // insert part contact
            
            Contact con= new Contact();
            con.RecordtypeId= customerContactRecordTypeId;
            con.FirstName =(String)accountData.get('contactPartsFirstName');
            con.LastName =(String)accountData.get('contactPartsLastName');
            con.Email=(String)accountData.get('contactPartsEmailAddress');            
            con.Phone=(String)accountData.get('contactPartsPhoneNumber'); 
            con.AccountId=ac.Id;
            con.NAC_Contact_Type__c = 'Parts Ordering';
            con.NAC_Status__c ='Pending';
            insert con;  
            
            //insert finance contact
             Contact fcon= new Contact();   
            fcon.RecordtypeId= customerContactRecordTypeId;                  
            fcon.FirstName =(String)accountData.get('contactFinanceFirstName');
            fcon.LastName =(String)accountData.get('contactFinanceLastName');
            fcon.Email=(String)accountData.get('contactFinanceEmailAddress');            
            fcon.Phone=(String)accountData.get('contactFinancePhoneNumber'); 
            fcon.AccountId=ac.Id;
            fcon.NAC_Contact_Type__c = 'Finance';
            fcon.NAC_Status__c ='Pending';
            insert fcon; 
         
            
            
            
           }catch(Exception e){
            Database.rollback(sp);
            isContactCreated = false;            
            system.debug('exception ' + e.getTypeName());
            system.debug('exception ' + e.getMessage());
            system.debug('exception ' + e.getStackTraceString());
        }
             
        isContactCreated= true;
        
        return isContactCreated;
        
    }

    @AuraEnabled
    public static Map<String,List<NAC_Country_and_State_Picklist__mdt>> fetchCountryandStates(){
        Map<String,List<NAC_Country_and_State_Picklist__mdt>> mapOfCountryWithStatesList = new Map<String,List<NAC_Country_and_State_Picklist__mdt>>();
        try {
            NAC_Country_and_State_Picklist__mdt[] results = [ SELECT Id,MasterLabel,DeveloperName, nac_Country__c,nac_Country_Code__c,
            nac_State__c,nac_State_Code__c,nac_Active__c FROM NAC_Country_and_State_Picklist__mdt Where nac_Active__c= true ORDER BY nac_Country__c];
            
            System.debug(results);
            if(results.size()>0){
                
                for(NAC_Country_and_State_Picklist__mdt cont : results)
                {
                    List<NAC_Country_and_State_Picklist__mdt> contList= new List<NAC_Country_and_State_Picklist__mdt>();
                    if(mapOfCountryWithStatesList.containsKey(cont.nac_Country__c)){
                        List<NAC_Country_and_State_Picklist__mdt> existingContList= new List<NAC_Country_and_State_Picklist__mdt>();
                        existingContList = mapOfCountryWithStatesList.get(cont.nac_Country__c);
                        existingContList.add(cont);
                        mapOfCountryWithStatesList.put(cont.nac_Country__c,existingContList);

                    }else{
                        contList.add(cont);
                        mapOfCountryWithStatesList.put(cont.nac_Country__c,contList);
                    }
                }
            }
            
        } catch (Exception ex) {
            //throw new AuraHandledException(e.getMessage());
        }
        return mapOfCountryWithStatesList;
    }
    
   

    
    
    public class userWrapper{
        @AuraEnabled public List<ContactPointAddress> addressList;
        userWrapper(){
            addressList = new List<ContactPointAddress>();
        }
    }




	    
}