public without sharing class NAC_InventoryUtility {
    //Method to get inventory based on product and warehouse
    @AuraEnabled
    public static NATT_ProductInventoryItem__c getProductAvailability(Id productId, String warehouse) {

        return [SELECT NATT_AvailableQuantity__c,NATT_AvailabilityDate__c,NATT_ProductItem__c,NATT_ProductItem__r.NATT_SignalCode__c,
                NATT_ProductItem__r.NAOCAP_Signal_Code_ANA__c,NATT_ProductItem__r.NAOCAP_Signal_Code_CHI__c,NATT_ProductItem__r.NAOCAP_Signal_Code_PAN__c,NATT_ProductItem__r.NATT_Core__c  
                FROM NATT_ProductInventoryItem__c
                WHERE NATT_ProductItem__c = :productId AND NATT_Warehouse__c =: warehouse LIMIT 1];
    }
    //Method to get inventory based on list of products and warehouse
    @AuraEnabled
    public static Map<Id, NATT_ProductInventoryItem__c> getCartAvailability(List<String> productIds, String warehouse) {
        Map<Id, NATT_ProductInventoryItem__c> piiMap = new Map<Id, NATT_ProductInventoryItem__c>();
        for (NATT_ProductInventoryItem__c pii : [
            SELECT
                NATT_AvailableQuantity__c,
                NATT_AvailabilityDate__c,
                NATT_ProductItem__c,
                NATT_ProductItem__r.NATT_SignalCode__c,
                NATT_ProductItem__r.NAOCAP_Signal_Code_ANA__c,NATT_ProductItem__r.NAOCAP_Signal_Code_CHI__c,NATT_ProductItem__r.NAOCAP_Signal_Code_PAN__c,NATT_ProductItem__r.NATT_Core__c 
            FROM NATT_ProductInventoryItem__c
            WHERE NATT_ProductItem__c = :productIds AND NATT_Warehouse__c =: warehouse
        ]) {
            piiMap.put(pii.NATT_ProductItem__c, pii);
        }
        return piiMap;
    }

    //Method to get inventory for all the warehouses for a product
    @AuraEnabled
    public static Map<String,NATT_ProductInventoryItem__c> getAllWarehouseAvailability(Id productId) {
        Map<String,NATT_ProductInventoryItem__c> productAndInventories = new Map<String,NATT_ProductInventoryItem__c>();
        for(NATT_ProductInventoryItem__c item:[SELECT NATT_AvailableQuantity__c,NATT_AvailabilityDate__c,NATT_ProductItem__c,NATT_ProductItem__r.NATT_SignalCode__c,NATT_Warehouse__c
                                                FROM NATT_ProductInventoryItem__c
                                                WHERE NATT_ProductItem__c = :productId]){
            productAndInventories.put(item.NATT_Warehouse__c,item);
        } 
        return productAndInventories;
    }
    
    
}