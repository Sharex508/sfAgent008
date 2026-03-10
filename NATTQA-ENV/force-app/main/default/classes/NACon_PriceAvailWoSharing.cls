public  without sharing class NACon_PriceAvailWoSharing  {
    
    @testVisible
    private static Boolean throwException = false;
    private static Boolean thrownewException = false;
    private static Boolean throwauraException = false;
    
       public static List<NATT_ItemPriceStaging__c> getQuantityBreakListPrices(){
        try {
            System.debug('Test');
            return new List<NATT_ItemPriceStaging__c>([SELECT Id, NATT_QuantityFrom__c,NATT_Product__c,NATT_Product__r.NATT_P_N__c,NATT_ListPrice__c  FROM NATT_ItemPriceStaging__c WHERE NATT_QuantityFrom__c>1 AND NATT_EffectiveDate__c<=TODAY AND NATT_ExpiryDate__c>=TODAY AND NATT_Product__c!=''AND NATT_CustomerNumber__c=0 AND RecordType.Name='NAOCAP' ORDER BY NATT_Product__c]);   
            
           // if(NACon_PriceAvailWoSharing.throwException){
              //  throw new AuraHandledException(e.getMessage());
           // }
            
            } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

}