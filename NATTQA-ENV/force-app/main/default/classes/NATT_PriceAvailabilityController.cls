public with sharing class NATT_PriceAvailabilityController {
    @AuraEnabled
    public static NATT_ProductInventoryItem__c getAvailable(String productId) {
        List<NATT_ProductInventoryItem__c> piiList = new List<NATT_ProductInventoryItem__c>(
            [ SELECT NATT_AvailableQuantity__c, NATT_AvailabilityDate__c,NATT_NSI_Availability__c 
            FROM NATT_ProductInventoryItem__c
            WHERE NATT_ProductItem__c = :productId AND NATT_Warehouse__c = 'ATL'
            LIMIT 1]);
        system.debug('---> pli' +piiList);
        system.debug('---> productId' +productId);
        if(!piiList.isEmpty()){
            return piiList.get(0);
        }else{
            return new NATT_ProductInventoryItem__c();
        }   
    }
    
     @AuraEnabled
    public static NATT_ProductInventoryItem__c getCtmAvailablity(string productId,string warehouse){
        List<NATT_ProductInventoryItem__c> piiList = new List<NATT_ProductInventoryItem__c>(
            [ SELECT NATT_AvailableQuantity__c,NATT_Warehouse__c, NATT_AvailabilityDate__c,NATT_NSI_Availability__c 
            FROM NATT_ProductInventoryItem__c
            WHERE NATT_ProductItem__c = :productId AND  NATT_ProductItem__r.RecordType.Name ='CTM Product' and NATT_Warehouse__c = :warehouse
            LIMIT 1]);
        system.debug('---> pli' +piiList);
        system.debug('---> productId' +productId);
        if(!piiList.isEmpty()){
            return piiList.get(0);
        }else{
            return new NATT_ProductInventoryItem__c();
        }   
    }

    
    @AuraEnabled
    public static String getSolutionCenterURL(){
        Network solutionId = [SELECT ID FROM Network WHERE Name = 'Carrier SolutionCenter'];
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
        /*
        //check if is original part and has been superseded
        List<NATT_AlternativeItem__c> pnHist = [
            SELECT Id, NATT_AlternativeItem__c, NATT_EffectiveDate__c
            FROM NATT_AlternativeItem__c
            WHERE NATT_ProductItem__c = :prodID
            ORDER BY NATT_EffectiveDate__c DESC
        ];
        
        List<Product2> prodHist = new List<Product2>();
        
        if (!pnHist.isEmpty()) {
            Set<Id> altItemIdSet = new Set<Id>();
            for (NATT_AlternativeItem__c ai : pnHist) {
                altItemIdSet.add(ai.NATT_AlternativeItem__c);
            }
            //go through original parts alternative items and add them to return list
            
            for(Product2 prod : [SELECT Id, NATT_P_N__c
                                FROM Product2
                                WHERE Id in :altItemIdSet]){
                prodHist.add(prod);
            }
            
            //add og part to list of part history
            Product2 prod = [SELECT Id, NATT_P_N__c FROM Product2 WHERE Id = :prodID];
            prodHist.add(prod);
        } else {
            //check if part has superseded original
            List<NATT_AlternativeItem__c> interm = [
                SELECT Id, NATT_ProductItem__c
                FROM NATT_AlternativeItem__c
                WHERE NATT_AlternativeItem__c = :prodID
                ORDER BY NATT_EffectiveDate__c
                LIMIT 1
            ];
            
            if (!interm.isEmpty()) {
                //get original parts alternative items list
                List<NATT_AlternativeItem__c> ogItemList = [
                    SELECT Id, NATT_AlternativeItem__c
                    FROM NATT_AlternativeItem__c
                    WHERE NATT_ProductItem__c = :interm[0].NATT_ProductItem__c
                    ORDER BY NATT_EffectiveDate__c DESC
                ];
                Set<Id> altItemIdSet = new Set<Id>();
                for(NATT_AlternativeItem__c ai : ogItemList){
                    altItemIdSet.add(ai.NATT_AlternativeItem__c);
                }
                //go through original parts alternative items and add them to return list
                for(Product2 prod : [SELECT Id, NATT_P_N__c
                                        FROM Product2
                                        WHERE Id IN :altItemIdSet]){
                    prodHist.add(prod);
                }
                
                //add og part to list of part history
                Product2 prod = [
                    SELECT Id, NATT_P_N__c
                    FROM Product2
                    WHERE Id = :interm[0].NATT_ProductItem__c
                ];
                prodHist.add(prod);
            } else {
                //if has never been superseded, add current part to part history
                Product2 prod = [SELECT Id, NATT_P_N__c
                                 FROM Product2
                                 WHERE Id = :prodID];
                prodHist.add(prod);
                //need to add part again because modal table starts at prodHist[1]
                prodHist.add(prod);
            }
        }        
        return prodHist;*/
    }
    
     /*@AuraEnabled
    public static ConnectApi.ProductDetail getUserGuide(String prodID) {

       
        List<ContentDocumentLink> file = [
            SELECT Id, LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :prodID
            LIMIT 1
        ];
        
        if (!file.isEmpty()) {
            List<ContentDocument> usrGuide = [
                SELECT Id, Title
                FROM ContentDocument
                WHERE Id = :file[0].ContentDocumentId
            ];
            return usrGuide;
        } else {
            List<ContentDocument> usrGuide = new List<ContentDocument>();
            return usrGuide;
        }
    }*/

    @AuraEnabled
    public static List<NATT_ItemPriceStaging__c> getQuantityBreakListPrices(){
        return NATT_PriceAvailWoSharing.getQuantityBreakListPrices();
    }
}