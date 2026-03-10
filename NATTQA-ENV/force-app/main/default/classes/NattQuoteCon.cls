public without sharing class NattQuoteCon {    
@AuraEnabled
public static Opportunity getOppData(String oppId) {
   if (String.isBlank(oppId)) {
        throw new AuraHandledException('Opportunity Id cannot be null or blank.');
    }
    
    return [
        SELECT Id, AccountId, Account.Name, OwnerId,
               NATT_Shipping_Address__c, NATT_Billing_Address__c,
               Pricebook2Id, SBQQ__PrimaryQuote__r.RecordType.Name
        FROM Opportunity
        WHERE Id = :oppId
    ];
}
@AuraEnabled public static string createOpportunityRecord(String strJSON, string quoteJSON) {
        Opportunity objOpportunity = (Opportunity) JSON.deserialize(strJSON, Opportunity.class);
        insert objOpportunity;
        return createQuote(objOpportunity.id,true,quoteJSON);
        //return objOpportunity.Id;
    }
   @AuraEnabled 
    public static Map<String, Object> getAddressJunctionDetails(String billingAddressId,String shippingAddressId) {
        Map<String, Object> resultMap = new Map<String, Object>();
        Set<Id> addressIds = new Set<Id>();
        if (billingAddressId != null) {
           addressIds.add(billingAddressId);
           }
        if (shippingAddressId != null) {
            addressIds.add(shippingAddressId);
          }
        if (!addressIds.isEmpty()) {
            List<Ctbr_Account_Address_Junction__c> junctionList = [
                SELECT Id, Type__c, CTBR_Address__c
                FROM Ctbr_Account_Address_Junction__c
                WHERE Id IN :addressIds
            ];
            if (!junctionList.isEmpty()) {
                for (Ctbr_Account_Address_Junction__c junction : junctionList) {
                    resultMap.put(junction.Id, junction.CTBR_Address__c);
                }
                resultMap.put('isSuccess',true);
            }
        }
        else{
            resultMap.put('isSuccess',false);
        }
        return resultMap;
    }
    @AuraEnabled public static String createQuote(String oppId, Boolean primaryQuote, string quoteJSON) {
        Boolean eSolutionsOpp = false;
        Boolean CTBRUnitsOpp = false;
        Map<String, Object> untypedObject = (Map<String, Object>) JSON.deserializeUntyped(quoteJSON);
        Opportunity opp = [SELECT Id,AccountId,Account.RecordType.DeveloperName,NATT_End_Customer__c,Name,NATT_End_Customer__r.Name,
                           RecordType.DeveloperName,NATT_Shipping_Address__r.NATT_Street__c,NATT_Shipping_Address__r.NATT_City__c,NATT_Shipping_Address__r.NATT_State_Province__c,
                           NATT_Shipping_Address__r.NATT_Zip_Postal_Code__c,NATT_Billing_Address__r.NATT_Street__c,
                           NATT_Billing_Address__r.NATT_Country__c,
                           NATT_Billing_Address__r.NATT_City__c,NATT_Billing_Address__r.NATT_State_Province__c,
                           NATT_Billing_Address__r.NATT_Zip_Postal_Code__c,NATT_Shipping_Address__r.NATT_Country__c,NATT_Stock__c,CTBR_Shipping_Address__r.CTBR_Address__c,CTBR_Billing_Address__r.CTBR_Address__c,
                           CTBR_Billing_Address__r.CTBR_Address__r.NATT_State_Province__c,CTBR_Billing_Address__r.CTBR_Address__r.CTBR_State_Province__c
                           FROM Opportunity WHERE Id=:oppId];
        SBQQ__Quote__c quote = new SBQQ__Quote__c();
        quote.SBQQ__Opportunity2__c=opp.Id;
        quote.SBQQ__Account__c=opp.AccountId;
        quote.QUO_Quote_Short_Description__c=opp.Name;        
        quote.SBQQ__BillingStreet__c=opp.NATT_Billing_Address__r.NATT_Street__c;
        quote.SBQQ__BillingCity__c=opp.NATT_Billing_Address__r.NATT_City__c;
        quote.SBQQ__BillingState__c=opp.NATT_Billing_Address__r.NATT_State_Province__c;
        quote.SBQQ__BillingPostalCode__c=opp.NATT_Billing_Address__r.NATT_Zip_Postal_Code__c;
        quote.SBQQ__BillingCountry__c=opp.NATT_Billing_Address__r.NATT_Country__c;
        quote.SBQQ__ShippingStreet__c=opp.NATT_Shipping_Address__r.NATT_Street__c;
        quote.SBQQ__ShippingCity__c=opp.NATT_Shipping_Address__r.NATT_City__c;
        quote.SBQQ__ShippingState__c=opp.NATT_Shipping_Address__r.NATT_State_Province__c;
        quote.SBQQ__ShippingPostalCode__c=opp.NATT_Shipping_Address__r.NATT_Zip_Postal_Code__c;
        quote.SBQQ__ShippingCountry__c=opp.NATT_Shipping_Address__r.NATT_Country__c;
        quote.SBQQ__Primary__c = primaryQuote;
        quote.NATT_End_Customer__c=opp.NATT_End_Customer__c;
        quote.NATT_Stock__c=opp.NATT_Stock__c;
        //CTBR Changes
        if(opp.RecordType.DeveloperName.contains('CTBR_Units')){
        quote.CTBR_Shipping_Address__c= opp.CTBR_Shipping_Address__c; //(Id)untypedObject.get('shippingAddress');
        quote.CTBR_Billing_Address__c=opp.CTBR_Billing_Address__c; //(Id)untypedObject.get('billingAddress');
        quote.NATT_Shipping_Address__c= opp.CTBR_Shipping_Address__r.CTBR_Address__c;
        quote.NATT_Billing_Address__c = opp.CTBR_Billing_Address__r.CTBR_Address__c;
        //quote.SBQQ__BillingState__c= opp.CTBR_Billing_Address__r.CTBR_Address__r.NATT_State_Province__c;
        quote.SBQQ__BillingState__c= opp.CTBR_Billing_Address__r.CTBR_Address__r.CTBR_State_Provicence__c;
        }
        if(opp.RecordType.DeveloperName.contains('eSolutions')){
            quote.RecordTypeId = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_eSolutions').getRecordTypeId();
            quote.NATT_Quote_Record_Type_Developer_Name__c='NATT_eSolutions';
            opp.Name = opp.NATT_End_Customer__r.Name+' - New Lynx Fleet Account';
            eSolutionsOpp = true;
        }else if(opp.RecordType.DeveloperName.contains('NATT_Opportunity_BluEdge')){
            quote.RecordTypeId=Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_BluEdge').getRecordTypeId();
            quote.NATT_Quote_Record_Type_Developer_Name__c='NATT_BluEdge';
        }else if(opp.RecordType.DeveloperName.contains('MX_Units')){
            quote.RecordTypeId=Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('MX_Units_Quote').getRecordTypeId();
            quote.NATT_Quote_Record_Type_Developer_Name__c='MX_Units_Quote';
        }else if(opp.RecordType.DeveloperName.contains('CTBR_Units')){
            quote.RecordTypeId=Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('CTBR_Units_Quote').getRecordTypeId();
            quote.NATT_Quote_Record_Type_Developer_Name__c='CTBR_Units_Quote';
            opp.NATT_Shipping_Address__c= opp.CTBR_Shipping_Address__r.CTBR_Address__c ;
            opp.NATT_Billing_Address__c  = opp.CTBR_Billing_Address__r.CTBR_Address__c;
            CTBRUnitsOpp = true;
        }else if(opp.RecordType.DeveloperName.contains('CTBR_BluEdge')){
            quote.RecordTypeId=Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('CTBR_BluEdge').getRecordTypeId();
            quote.NATT_Quote_Record_Type_Developer_Name__c='CTBR_BluEdge';
        }
        else if(opp.RecordType.DeveloperName.contains('CTM_BluEdge')){
            quote.RecordTypeId=Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('CTM_BluEdge').getRecordTypeId();
            quote.NATT_Quote_Record_Type_Developer_Name__c='CTM_BluEdge';
        } else if(opp.RecordType.DeveloperName == 'NATT_Direct_Sales'){
            quote.RecordTypeId=Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_Direct_Sales').getRecordTypeId();
            quote.NATT_Quote_Record_Type_Developer_Name__c='NATT_Direct_Sales';
            quote.Mark_For_Location_Country__c = (String) untypedObject.get('MarkForCountry');
            quote.Mark_For_Location_State__c = (String) untypedObject.get('MarkForState');
            quote.Mark_For_Location_City__c = (String) untypedObject.get('MarkForCity');
            quote.NATT_Purchase_Order__c = (String) untypedObject.get('poNumber');
            quote.NATT_Has_Freight__c = (Boolean) untypedObject.get('hasFreight');
        }
        else{
            quote.RecordTypeId=Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_Units_Quote').getRecordTypeId();
            quote.NATT_Quote_Record_Type_Developer_Name__c='NATT_Units_Quote';
            if(opp.Account.RecordType.DeveloperName=='Internal'){                
                quote.RecordTypeId=Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_Internal_Customer').getRecordTypeId();                
                quote.NATT_Quote_Record_Type_Developer_Name__c='NATT_Internal_Customer';
            }
        } 
        try{
            insert quote;
            if(eSolutionsOpp){
                update opp;
            }
             if (CTBRUnitsOpp)
            {
                update opp;
            }
            return quote.Id;
        }catch(Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }    
    @AuraEnabled 
    public static Wrapper getData(String accountId){
        Wrapper w = new Wrapper();
        w.dealerId=accountId;
        w.isBluedge=false;
        w.isEsolutions=false;
        w.isCTMUnit=false;
        // Check field-level permission for the Billing field on the NATT_Addresses__r relationship
        Account a = [SELECT RecordType.DeveloperName,NATT_Dealership__c,(SELECT Id FROM NATT_Addresses__r WHERE NATT_Type__c='Billing' AND NATT_Deactivated__c = False) FROM Account where Id=:accountId];
        User u = [SELECT Id,ContactId,Contact.AccountId,Profile.Name FROM User WHERE Id=:UserInfo.getUserId()];
        //Id endCustomerId;
        if(u.ContactId!=null){
            if(a.RecordType.DeveloperName!='Dealer' && a.RecordType.DeveloperName!='MX_Dealer' && a.RecordType.DeveloperName!='CTBR_Dealer'){
                w.endCustomerId=a.Id;
                w.dealerId=a.NATT_Dealership__c;
            } else if(u.Contact.AccountId!=a.Id){
                w.dealerId=a.Id;
            }
        }
        for(NATT_Address__c add : a.NATT_Addresses__r){
            w.defaultBillingAddressId=add.Id;
        }
        w.oppRtList = new List<Map<String,String>>();
        w.nattPbMap = new Map<String,Id>();
        w.oppRtMap = new Map<Id,String>();
        w.rtToPbMap = new Map<Id,Id>();
        Map<String,Schema.RecordTypeInfo> recordTypeInfoMap = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName();
        for(Pricebook2 pb : [SELECT ID,Name FROM Pricebook2 WHERE (Name like 'NATT%' OR Name like 'MX%' OR Name like 'CTBR%' OR Name Like 'CTM%') AND IsActive=true]){
            w.nattPbMap.put(pb.Name,pb.Id);           
        }        
        String label;
        String rtId;
        if(a.RecordType.DeveloperName == 'NATT_OEM'){
            RecordTypeInfo dirSaleRecType = recordTypeInfoMap.get('NATT_Direct_Sales');
            label = dirSaleRecType.getName();
            rtId = dirSaleRecType.getRecordTypeId();
            w.oppRtMap.put(rtId,label);
            w.oppRtList.add(new Map<String,String>{'value'=>rtId,'label'=>label});
            w.defaultRtId = rtId;
            w.endCustomerId = a.Id;
            w.dealerId = a.id;
            w.isDirectSale = true;
            Id recordTypeId = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_Direct_Sales').getRecordTypeId();
            w.dirSalesQuoteRtId = recordTypeId;
            w.rtToPbMap.put(rtId, w.nattPbMap.get('NATT Units Price Book'));
            return w;
        }
        for(RecordTypeInfo info : recordTypeInfoMap.values()) {
            if(info.isAvailable() && (
                info.getDeveloperName().startsWith('NATT') || 
                info.getDeveloperName().startsWith('MX') || info.getDeveloperName().startsWith('CTM') || info.getDeveloperName().startsWith('CTBR'))){
                    label = info.getName();
                    rtId = info.getRecordTypeId();
                    w.oppRtMap.put(rtId,label);
                    /* To remove record type access for natt full access communiyt and Sales only Modified 181 to 193*/
                    if (u.Profile.Name == 'NATT Full Access Community' || u.Profile.Name == 'NATT Sales Only Community') {
                        // Skip NATT_Opportunity_Parts and NATT_Opportunity_Units for this profile
                        if (info.getDeveloperName() != 'NATT_Opportunity_Parts' && 
                            info.getDeveloperName() != 'NATT_Opportunity_Units') {
                                w.oppRtMap.put(rtId, label);
                                w.oppRtList.add(new Map<String, String>{'value' => rtId, 'label' => label});
                            }
                    } else {
                        // For all other profiles, include all applicable record types
                        w.oppRtMap.put(rtId, label);
                        w.oppRtList.add(new Map<String, String>{'value' => rtId, 'label' => label});
                    }
                    if(label.contains('Parts')){
                        w.rtToPbMap.put(rtId,w.nattPbMap.get('NATT Parts Price Book'));            
                    }else if(label.contains('Units') && !label.contains('MX Units') && !label.contains('CTM Units') && !label.contains('CTBR Units')){
                        w.rtToPbMap.put(rtId,w.nattPbMap.get('NATT Units Price Book'));
                    }else if(label.contains('BluEdge') && !label.contains('CTBR BluEdge') && !label.contains('CTM BluEdge') ){
                        w.rtToPbMap.put(rtId,w.nattPbMap.get('NATT BluEdge'));
                        w.isBluEdge=info.isDefaultRecordTypeMapping();                    
                    }else if(label.contains('Lynx Fleet')){
                        w.rtToPbMap.put(rtId,w.nattPbMap.get('NATT Lynx Fleet'));
                        //  w.isEsolutions=info.isDefaultRecordTypeMapping();
                    }else if(label.contains('CTBR Units')){
                        w.rtToPbMap.put(rtId,w.nattPbMap.get('CTBR Units Price Book'));
                        w.isCTBRUnit=info.isDefaultRecordTypeMapping();
                    }else if(label.contains('CTBR BluEdge')){
                        w.rtToPbMap.put(rtId,w.nattPbMap.get('CTBR BluEdge'));
                        w.isCTBRBluEdge=info.isDefaultRecordTypeMapping();
                    }else if(label.contains('MX Units') || label.contains('CTM Units')){
                        w.rtToPbMap.put(rtId,w.nattPbMap.get('MX Units Price Book'));
                        w.isCTMUnit=info.isDefaultRecordTypeMapping();
                    }else if( label.contains('CTM BluEdge')){
                        w.rtToPbMap.put(rtId,w.nattPbMap.get('CTM BluEdge'));
                        w.isCTMUnit=info.isDefaultRecordTypeMapping();
                        w.isBluedge=true;
                    }
                    if(info.isDefaultRecordTypeMapping()){
                        w.defaultRtId=rtId;                   
                    }
                    //Added by khushmeet to identify if the logged in user is internal user
                    User currentUser = [SELECT UserType FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
                    if (currentUser.UserType == 'Standard') {
                        w.isInternalUser = true;              
                    }
                }
        }
        return w;
    }
    
     
    @TestVisible
    class Wrapper{
        @AuraEnabled public List<Map<String, String>> oppRtList {get;set;} 
        @AuraEnabled public Map<String,Id> nattPbMap {get;set;}
        @AuraEnabled public Map<Id,String> oppRtMap {get;set;}
        @AuraEnabled public String defaultRtId {get;set;}
        @AuraEnabled public String dealerId {get;set;}
        @AuraEnabled public String endCustomerId {get;set;}
        @AuraEnabled public String defaultBillingAddressId {get;set;}
        @AuraEnabled public Map<Id,Id> rtToPbMap {get;set;}
        @AuraEnabled public boolean isBluEdge {get;set;}
        @AuraEnabled public boolean isEsolutions {get;set;}
        @AuraEnabled public boolean isCTMUnit {get;set;}
        @AuraEnabled public boolean isCTBRUnit {get;set;}
        @AuraEnabled public boolean isCTBRBluEdge {get;set;}
        @AuraEnabled public boolean isDirectSale {get;set;}
        @AuraEnabled public String dirSalesQuoteRtId{get;set;}
        @AuraEnabled public boolean isInternalUser{get;set;}
    }

    @AuraEnabled public static boolean getLoggedInUser() {
        User currentUser = [SELECT UserType FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (currentUser.UserType == 'Standard') {
            return true;
        }
        else{
            return false;
        }
    }
}