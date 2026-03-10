public without sharing class NATT_TesTrademarkCon {
    @AuraEnabled(cacheable=true)
    public static ProductCategory getProductCategory(String recordId){
        try {
            return [SELECT Id,Name FROM ProductCategory WHERE Id=:recordId];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
}