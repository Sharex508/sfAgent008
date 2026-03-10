public without sharing class ucp_serviceAgreement {
    
    @AuraEnabled
    public static Boolean verifyUserDetails() {
        Boolean isValidUser = false;
        
        // Retrieve current user details
        User objUser;
        try {
            
            objUser = [SELECT Id, Name,AccountId,ContactId,Container_Service_Agreement__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            if(objUser.Container_Service_Agreement__c == true){
                isValidUser = true;
            }
            else{
                isValidUser = false;
            }
            
        }
        catch (Exception e) {
            system.debug('An error occurred: ' + e.getMessage());
            return false; // Exit early if the contact is not found
        }
        
        return isValidUser;
    }
    
    
    
    @AuraEnabled
    public static List<CONTAINER_Service_Agreement__c> getServiceAgreementRecord(){
        String strUserId = UserInfo.getUserId();
        User objUser = [SELECT Id,Name,AccountId FROM User WHERE Id=:strUserId and Container_Service_Agreement__c = true];
        system.debug('objUser--'+ objUser); 
        try {
            String strAccountId;
            List<CONTAINER_Service_Agreement__c> list_serviceAgreement = new List<CONTAINER_Service_Agreement__c>();
            Account objAccount = [SELECT Id,Name,Authorized_Service_Provider__c,RecordType.Name FROM Account WHERE Id=: objUser.AccountId];
            if(objAccount.RecordType.Name == 'CONTAINER Authorized Service Provider'){
                strAccountId = objAccount.Id;
            }
            else{
                strAccountId = objAccount.Authorized_Service_Provider__c;
            }
            
            if(!String.isEmpty(strAccountId) || !String.isBlank(strAccountId))
            {
                list_serviceAgreement = [SELECT Id,Name,Account__r.Name,Account__c,
                                         CONTAINER_Agreement_End_Date__c,
                                         CONTAINER_Agreement_Start_Date__c,
                                         Primary_Contact__c
                                         FROM CONTAINER_Service_Agreement__c WHERE Account__c=:strAccountId];
            }
            return list_serviceAgreement;
            
        } catch (Exception e) {
            system.debug('exception'+e);
            return null;  
        }
        
    }
}