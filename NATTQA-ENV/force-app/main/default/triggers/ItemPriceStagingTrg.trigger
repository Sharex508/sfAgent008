trigger ItemPriceStagingTrg on NATT_ItemPriceStaging__c (after insert) {
    if(trigger.isAfter){
        if(trigger.isInsert){
            ItemPriceStagingTrgHandler.onAfterInsert(trigger.new);
        }
    }
}