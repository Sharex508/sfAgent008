public with sharing class NACon_PriceAvailabilityController {
    
     @AuraEnabled
    public static NATT_ProductInventoryItem__c getAvailable(String productId, Boolean isCtmStore, String acctId) {
        Account accountGrab = [SELECT NATT_Region__c FROM Account WHERE ID = :acctId];
        String warehouse = '';
        if(accountGrab.NATT_Region__c == 'Mexico'){
            warehouse = 'MEX';
        }else if(accountGrab.NATT_Region__c == 'Latin America'){
            warehouse = 'MIA';
        }else{
            warehouse = 'ATL';
        }
        System.debug('Warehouse Value: ' + warehouse);
        List<NATT_ProductInventoryItem__c> piiList = new List<NATT_ProductInventoryItem__c>(
            [ SELECT NATT_AvailableQuantity__c, NATT_AvailabilityDate__c,NATT_NSI_Availability__C
            FROM NATT_ProductInventoryItem__c
            WHERE NATT_ProductItem__c = :productId AND NATT_Warehouse__c = :warehouse
            LIMIT 1]);
        if(!piiList.isEmpty()){
            return piiList.get(0);
        }else{
            return new NATT_ProductInventoryItem__c();
        }        
    }

    @AuraEnabled
    public static String getNAContainerURL(){
        Network solutionId = [SELECT ID FROM Network WHERE Name = 'NA Containers Marketplace'];
        ConnectApi.Community solutionCenter = ConnectApi.Communities.getCommunity(solutionId.Id);
        return solutionCenter.siteUrl;
    }

    @AuraEnabled
    public static List<Product2> getHistory(String prodID) {
        
        List<Product2> returnList = new List<Product2>();
        //get the current product to add to the list
        Product2 currentProduct = [SELECT Id,NATT_P_N__c FROM Product2 WHERE Id=:prodId];
        
        //get any products that replace the current product
        for(NATT_AlternativeItem__c altItem : [SELECT Id, NATT_AlternativeItem__c, NATT_AlternativeItem__r.NATT_P_N__c 
                                               FROM NATT_AlternativeItem__c 
                                               WHERE NATT_ProductItem__c=:prodId 
                                               AND NATT_ProductItem__r.NATT_SignalCode__c='S2'
                                               ORDER BY NATT_EffectiveDate__c DESC]){
            returnList.add(new Product2(Id=altItem.NATT_AlternativeItem__c,NATT_P_N__c=altItem.NATT_AlternativeItem__r.NATT_P_N__c));
        }

        if(returnList.isEmpty()){     
            returnList.add(currentProduct);
        }

        //get all the products that have been superseded
        List<NATT_AlternativeItem__c> altItemList = new List<NATT_AlternativeItem__c>([SELECT Id,NATT_ProductItem__c,NATT_ProductItem__r.NATT_P_N__c 
                                            FROM NATT_AlternativeItem__c WHERE NATT_AlternativeItem__c=:prodId
                                            ORDER BY NATT_EffectiveDate__c DESC]);
        for(NATT_AlternativeItem__c altItem : altItemList){
            returnList.add(new Product2(Id=altItem.NATT_ProductItem__c,NATT_P_N__c=altItem.NATT_ProductItem__r.NATT_P_N__c));
        }
        if(altItemList.isEmpty()){
            returnList.add(currentProduct);
            //need to add part again because modal table starts at prodHist[1]
            returnList.add(currentProduct);
        }
        return returnList;        
    }

    @AuraEnabled
    public static List<NATT_ItemPriceStaging__c> getQuantityBreakListPrices(){
        return NACon_PriceAvailWoSharing.getQuantityBreakListPrices();
    }

}