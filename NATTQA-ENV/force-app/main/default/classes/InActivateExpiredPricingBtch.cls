global class InActivateExpiredPricingBtch  implements Database.Batchable<sObject>,  database.stateful {
    global Database.QueryLocator start(Database.BatchableContext BC) {
        string query = 'select id,NATT_CustomerNumber__c,NATT_Product__c, NATT_ExpiryDate__c,NATT_ItemNumber__c from NATT_ItemPriceStaging__c  where NATT_CustomerNumber__c != 0  and   NATT_ExpiryDate__c<today order by NATT_ExpiryDate__c desc';
        return Database.getQueryLocator(query); 
    }
    
    global void execute(Database.BatchableContext BC, List<NATT_ItemPriceStaging__c> scope) {
        try{
            set<Id> prodId = new set<Id>(); 
            set<string> custNumberSet = new set<string>();
            list<PricebookEntry> pbEntryList = new list<PricebookEntry>();
            list<PricebookEntry> pbEntriersToUpdate = new list<PricebookEntry>();
            map<string, NATT_ItemPriceStaging__c> recentPASMap = new map<string, NATT_ItemPriceStaging__c>();
            
            for(NATT_ItemPriceStaging__c pas : scope){
                string productId = pas.NATT_Product__c ; 
                string customerNum = String.valueOf( pas.NATT_CustomerNumber__c );
                custNumberSet.add(customerNum);
                if( ! (recentPASMap.containsKey(productId+ customerNum))){
                recentPASMap.put( productId+customerNum  , pas );
                }
               
            }
            system.debug('recentPASMap-'+recentPASMap.size() );
            for(NATT_ItemPriceStaging__c pas : recentPASMap.values()) {
                prodId.add(pas.NATT_Product__c);
            }
            
            list<product2> productList = [ SELECT Id, Name, (select id,Name,Product2Id, NATT_Effective_Date__c,Pricebook2Id, Pricebook2.Name,IsActive from PricebookEntries where  Pricebook2.name =:custNumberSet and isActive=true ) FROM product2 where id =: prodId];
            system.debug('productList-'+productList.size());
            for(product2 prod: productList ){
                pbEntryList.addall(prod.PricebookEntries);
            }
            system.debug('pbEntryList-'+pbEntryList.size());
            for (PricebookEntry pbe : pbEntryList){
                If(pbe.IsActive == True){
                pbe.IsActive = false;
                pbEntriersToUpdate.add(pbe);
                }
            }
            system.debug('pbEntriersToUpdate-'+pbEntriersToUpdate.size());
            if (!pbEntriersToUpdate.isEmpty() ) {
                Database.SaveResult[] saveResults = Database.update (pbEntriersToUpdate,false);
            }
        } 
        catch(exception e){
            system.debug('line-'+e.getLineNumber ()+'-error- '+e);
        }
    }
    
    global void finish(Database.BatchableContext BC) {
        
    }
   
    
}