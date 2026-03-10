public class NattAddressSelectionCon {
    @AuraEnabled public static Wrapper getAddressList(String dealerId,String endCustomerId,String addressType){
        Wrapper w = new Wrapper();
        Set<String> accountIdSet = new Set<String>{dealerId,endCustomerId};
            accountIdSet.remove(null);
        accountIdSet.remove('');
        dealerId = String.isBlank(dealerId)?'':dealerId;
        endCustomerId = String.isBlank(endCustomerId)?'':endCustomerId;
        for(Account a : [SELECT Id,Name,
                         (SELECT Id,NATT_Account__c,NATT_Account__r.Name,NATT_JDE_Alpha_Name__c, NATT_Address_Formatted__c,NATT_Account_Record_Type_Developer_Name__c 
                          FROM NATT_Addresses__r WHERE NATT_Type__c=:addressType AND NATT_Deactivated__c = False
                          ORDER BY NATT_JDE_Alpha_Name__c) 
                         FROM Account WHERE Id in :accountIdSet]){                             
                             if(String.isNotBlank(dealerId) && dealerId==a.Id){
                                 w.dealerName=a.Name;
                             }else if(String.isNotBlank(endCustomerId) && endCustomerId==a.Id){
                                 w.endCustomerName=a.Name;
                             }
                             for(NATT_Address__c address : a.NATT_Addresses__r){                                 
                                 if(String.isNotBlank(dealerId) && address.NATT_Account__c==dealerId && !address.NATT_Account_Record_Type_Developer_Name__c.contains('MX') && !address.NATT_Account_Record_Type_Developer_Name__c.contains('CTBR')){
                                     w.dealerAddressList.add(new Map<String,String>{'value'=>address.Id,'label'=>address.NATT_Address_Formatted__c});
                                     if(addressType=='Billing'){
                                         w.defaultBillingAddressId=address.Id;
                                     }
                                 }else if(String.isNotBlank(endCustomerId) && address.NATT_Account__c==endCustomerId && !address.NATT_Account_Record_Type_Developer_Name__c.contains('CTBR')){
                                     w.endCustomerAddressList.add(new Map<String,String>{'value'=>address.Id,'label'=>address.NATT_Address_Formatted__c});
                                 }else if(String.isNotBlank(endCustomerId) && address.NATT_Account__c==endCustomerId && address.NATT_Account_Record_Type_Developer_Name__c.contains('CTBR')){
                                     w.endCustomerAddressListCTBR.add(new Map<String,String>{'value'=>address.Id,'label'=>address.NATT_Address_Formatted__c});
                                 }else if(String.isNotBlank(dealerId) && address.NATT_Account__c==dealerId && address.NATT_Account_Record_Type_Developer_Name__c.contains('MX')){
                                     w.dealerAddressListCTM.add(new Map<String,String>{'value'=>address.Id,'label'=>address.NATT_Address_Formatted__c});
                                 }else if(String.isNotBlank(dealerId) && address.NATT_Account__c==dealerId && address.NATT_Account_Record_Type_Developer_Name__c.contains('CTBR')){
                                     w.dealerAddressListCTBR.add(new Map<String,String>{'value'=>address.Id,'label'=>address.NATT_Address_Formatted__c});
                                     if(addressType=='Billing'){
                                         w.defaultBillingAddressId=address.Id;
                                     }
                                 }
                             }
                         }
        
        return w;
    }
    
    @AuraEnabled public static SBQQ__Quote__c getQuoteInfo(String qId){        
        return [SELECT Id,SBQQ__Opportunity2__c,SBQQ__Account__c,SBQQ__Opportunity2__r.NATT_End_Customer__c,SBQQ__Opportunity2__r.NATT_Billing_Address__c,SBQQ__Opportunity2__r.NATT_Shipping_Address__c FROM SBQQ__Quote__c WHERE Id=:qId];
    }
    
    @AuraEnabled public static Order getOrderInfo(String oId){        
        return [SELECT Id,AccountId,NATT_End_Customer__c,NATT_Billing_Address__c,NATT_Shipping_Address__c FROM Order WHERE Id=:oId];
    }
    
    @AuraEnabled public static void updateQuote(String quoteId,String oppId,String billingAddressId, String shippingAddressId){
        try{
            Opportunity opp = new Opportunity(Id=oppId,NATT_Billing_Address__c=billingAddressId,NATT_Shipping_Address__c=shippingAddressId);
            update opp;
            
            opp = [SELECT Id,AccountId,Account.RecordType.DeveloperName,Name,RecordType.DeveloperName,NATT_Shipping_Address__r.NATT_Street__c,NATT_Shipping_Address__r.NATT_City__c,NATT_Shipping_Address__r.NATT_State_Province__c,
                   NATT_Shipping_Address__r.NATT_Zip_Postal_Code__c,NATT_Billing_Address__r.NATT_Street__c,NATT_Billing_Address__r.NATT_Country__c,
                   NATT_Billing_Address__r.NATT_City__c,NATT_Billing_Address__r.NATT_State_Province__c,NATT_Billing_Address__r.NATT_Zip_Postal_Code__c,NATT_Shipping_Address__r.NATT_Country__c
                   FROM Opportunity WHERE Id=:oppId];
            
            SBQQ__Quote__c quote = new SBQQ__Quote__c(Id=quoteId);            
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
            
            update quote;
        }catch(Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled public static void updateOrder(String orderId,String billingAddressId, String shippingAddressId){
        try{
            Order o = new Order(Id=orderId,NATT_Billing_Address__c=billingAddressId,NATT_Shipping_Address__c=shippingAddressId);
            update o;
            
            o = [SELECT Id,NATT_Shipping_Address__r.NATT_Street__c,NATT_Shipping_Address__r.NATT_City__c,NATT_Shipping_Address__r.NATT_State_Province__c,
                 NATT_Shipping_Address__r.NATT_Zip_Postal_Code__c,NATT_Billing_Address__r.NATT_Street__c,NATT_Billing_Address__r.NATT_Country__c,
                 NATT_Billing_Address__r.NATT_City__c,NATT_Billing_Address__r.NATT_State_Province__c,NATT_Billing_Address__r.NATT_Zip_Postal_Code__c,NATT_Shipping_Address__r.NATT_Country__c
                 FROM Order WHERE Id=:o.Id];
            
            
            o.BillingStreet=o.NATT_Billing_Address__r.NATT_Street__c;
            o.BillingCity=o.NATT_Billing_Address__r.NATT_City__c;
            o.BillingState=o.NATT_Billing_Address__r.NATT_State_Province__c;
            o.BillingPostalCode=o.NATT_Billing_Address__r.NATT_Zip_Postal_Code__c;
            o.BillingCountry=o.NATT_Billing_Address__r.NATT_Country__c;
            o.ShippingStreet=o.NATT_Shipping_Address__r.NATT_Street__c;
            o.ShippingCity=o.NATT_Shipping_Address__r.NATT_City__c;
            o.ShippingState=o.NATT_Shipping_Address__r.NATT_State_Province__c;
            o.ShippingPostalCode=o.NATT_Shipping_Address__r.NATT_Zip_Postal_Code__c;
            o.ShippingCountry=o.NATT_Shipping_Address__r.NATT_Country__c;
            update o;
            
        }catch(Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @TestVisible
    class Wrapper{
        @AuraEnabled public List<Map<String, String>> dealerAddressList {get;set;}        
        @AuraEnabled public List<Map<String, String>> endCustomerAddressList {get;set;}
        @AuraEnabled public List<Map<String, String>> dealerAddressListCTM {get;set;}
        @AuraEnabled public List<Map<String, String>> dealerAddressListCTBR {get;set;}
        @AuraEnabled public List<Map<String, String>> endCustomerAddressListCTBR {get;set;}
        @AuraEnabled public String dealerName {get;set;}
        @AuraEnabled public String endCustomerName {get;set;}
        @AuraEnabled public String defaultBillingAddressId {get;set;}
        
        public Wrapper(){
            dealerAddressList = new List<Map<String, String>>();
            endCustomerAddressList = new List<Map<String, String>>();
            dealerAddressListCTM = new List<Map<String, String>>();
            dealerAddressListCTBR = new List<Map<String, String>>();
            endCustomerAddressListCTBR = new List<Map<String, String>>();
        }
    }
}