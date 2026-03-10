trigger PriceAdjustmentStagingTrg on NATT_PriceAdjustmentStaging__c (after insert) {
    if(trigger.isAfter){
        if(trigger.isInsert){
            PriceAdjustmentStagingTrgHandler.onAfterInsert(trigger.newMap);
        }
    }
}