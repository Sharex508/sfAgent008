public with sharing class OpportunityQuoteCreationController {
    
    @AuraEnabled(cacheable=true)
    public static List<RecordType> getRecordTypes(String objName,Id recordId){
        try {
            
            User currentUser = [SELECT Profile.Name, UserType FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
           
            if(objName == 'Opportunity') {
                
                 Account objAccount = [SELECT Id,Name,RecordType.DeveloperName FROM Account WHERE Id=:recordId LIMIT 1];
            
                // Align Opportunity behavior with Quote logic for CTM community users:
                // If Partner community user with CTM Full Access Community profile, prefer MX_Units
                if (currentUser.UserType != null && currentUser.UserType.contains('Partner') && currentUser.Profile.Name == 'CTM Full Access Community') {
                    return [SELECT Id, DeveloperName, Name 
                            FROM RecordType 
                            WHERE SObjectType = :objName
                            AND DeveloperName IN ('MX_Units')
                            AND IsActive = true
                            WITH SECURITY_ENFORCED];
                } else if (currentUser.UserType == 'Partner') {
                    return [SELECT Id, DeveloperName, Name 
                            FROM RecordType 
                            WHERE SObjectType = :objName
                            AND DeveloperName IN ('MX_Units','NATT_Opportunity_Units') 
                            AND IsActive = true
                            WITH SECURITY_ENFORCED];
                } else {
                    if(objAccount.RecordType.DeveloperName == 'NATT_OEM'){
                    return [SELECT Id, DeveloperName, Name 
                            FROM RecordType 
                            WHERE SObjectType = :objName
                            AND DeveloperName IN ('NATT_Direct_Sales')
                            AND IsActive = true
                            WITH SECURITY_ENFORCED];
                }
                    else{
                        return [SELECT Id, DeveloperName, Name 
                            FROM RecordType 
                            WHERE SObjectType = :objName
                            AND DeveloperName IN ('NATT_Opportunity_Units') 
                            AND IsActive = true
                            WITH SECURITY_ENFORCED];
                    }
                }
            } else {
                
                Opportunity objOpportunity = [SELECT Id,Name,RecordType.DeveloperName FROM Opportunity WHERE Id=:recordId LIMIT 1];
                
				if (currentUser.UserType != null && currentUser.UserType.contains('Partner')) {
                   
                    if(currentUser.Profile.Name == 'CTM Full Access Community'){
                        
                        return [SELECT Id, DeveloperName, Name 
                            FROM RecordType 
                            WHERE SObjectType = :objName
                            AND DeveloperName IN ('MX_Units_Quote')
                            AND IsActive = true
                            WITH SECURITY_ENFORCED];
                    }
                    else{
                        return [SELECT Id, DeveloperName, Name 
                                FROM RecordType 
                                WHERE SObjectType = :objName
                                AND DeveloperName IN ('NATT_Units_Quote')
                                AND IsActive = true
                                WITH SECURITY_ENFORCED];
                    }
                } else {
                    if(objOpportunity.RecordType.DeveloperName == 'NATT_Direct_Sales'){
                        return [SELECT Id, DeveloperName, Name 
                                FROM RecordType 
                                WHERE SObjectType = :objName
                                AND DeveloperName IN ('NATT_Direct_Sales')
                                AND IsActive = true
                                WITH SECURITY_ENFORCED];
                    }
                    else{
                    return [SELECT Id, DeveloperName, Name 
                            FROM RecordType 
                            WHERE SObjectType = :objName
                            AND DeveloperName IN ('NATT_Units_Quote')
                            AND IsActive = true
                            WITH SECURITY_ENFORCED]; 
                }
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // Other methods remain unchanged
    public static String getPricebookFromRecordTypes(Id recordTypeId){
        Map<String, String> recordTypeToPriceBook = new Map<String, String>{
            'NATT_Opportunity_BluEdge' => 'NATT BluEdge',
                'NATT_Opportunity_eSolutions' => 'NATT Lynx Fleet',
                'NATT_Opportunity_Parts' => 'NATT Parts Price Book',
                'NATT_Opportunity_Units' => 'NATT Units Price Book',
                'NATT_Direct_Sales' => 'NATT Units Price Book',
                'MX_Units' => 'MX Units Price Book'
                };
                    
                    try {
                        RecordType rt = [SELECT Id, DeveloperName, Name 
                                         FROM RecordType 
                                         WHERE Id = :recordTypeId
                                         AND IsActive = true
                                         WITH SECURITY_ENFORCED];
                        
                        if(recordTypeToPriceBook.containsKey(rt.DeveloperName)){
                            List<Pricebook2> priceBookList = [SELECT Id, Name, IsActive, IsStandard 
                                                              FROM Pricebook2 
                                                              WHERE Name = :recordTypeToPriceBook.get(rt.DeveloperName) 
                                                              AND IsActive = true
                                                              WITH SECURITY_ENFORCED];
                            if(!priceBookList.isEmpty()){
                                return priceBookList[0].Id;
                            } else {
                                return null;
                            }
                        } else{
                            return null;
                        }
                        
                    } catch (Exception e) {
                        throw new AuraHandledException(e.getMessage());
                    }
    }
    
    @AuraEnabled
    public static void updatePricebookOnOpportunity(Id oppId, Id recordTypeId) {
        try {
            Opportunity opp = [SELECT Id, Pricebook2Id 
                               FROM Opportunity 
                               WHERE Id = :oppId 
                               WITH SECURITY_ENFORCED  
                               LIMIT 1];
            
            opp.Pricebook2Id = getPricebookFromRecordTypes(recordTypeId);
            
            if(Schema.sObjectType.Opportunity.isUpdateable()){
                update opp;
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Opportunity_Scheduled_Pick_Date__c> getScheduledPickDates(Id opportunityId){
        system.debug(opportunityId);
        try {
            if(opportunityId == null){
                throw new AuraHandledException('Opportunity ID is required.');
            }
            return [
                SELECT Id, Name, Scheduled_Date__c
                FROM Opportunity_Scheduled_Pick_Date__c
                WHERE Opportunity__c = :opportunityId
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            system.debug(e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<OpportunityLineItem> getOpportunityProducts(Id opportunityId){
        system.debug(opportunityId);
        try {
            if(opportunityId == null){
                throw new AuraHandledException('Opportunity ID is required.');
            }
            return [
                SELECT Id, Name
                FROM OpportunityLineItem
                WHERE OpportunityId = :opportunityId
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            system.debug(e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<NATT_Address__c> addressFromAccount(Id accountId) {
    return [
        SELECT Id, Name, NATT_Type__c 
        FROM NATT_Address__c 
        WHERE (NATT_Type__c = 'Billing' OR NATT_Type__c = 'Units Ship To') 
        AND NATT_Account__c = :accountId
    ];
    }

    @AuraEnabled(cacheable=true)
    public static String getUserInfo(Id opportunityId) {
        Opportunity objOpportunity = [SELECT ID,Name,RecordType.DeveloperName FROM Opportunity WHERE Id=:opportunityId];
        
        User currentUser = [SELECT UserType FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if(objOpportunity.RecordType.DeveloperName == 'NATT_Direct_Sales' && currentUser.UserType == 'Standard'){
             return currentUser.UserType; 
        }
        return null; 
    }
}