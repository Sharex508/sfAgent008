trigger ExchangeRate_Trigger on Exchange_Rate__c (before update,after update) {
    if(trigger.isafter && trigger.isupdate){
        /*Map<String, Object> currentRateMap = new Map<String, Object>();
        Map<String, Object> previousRateMap = new Map<String, Object>();
        for(Exchange_Rate__c exRates : trigger.new){
            if(exRates.Name == 'CTBR Units'){
                currentRateMap.put('Current_Rate__c', exRates.CTBR_Current_Rate__c);
                ExchangeRateMetadataUtil.updateCustomMetadata('CTBR_Exchange_Rate__mdt','CTBR_Units', 'CTBR Units',currentRateMap);
                previousRateMap.put('Yesterday_Rate__c', exRates.CTBR_Previous_Rate__c);
                ExchangeRateMetadataUtil.updateCustomMetadata('CTBR_Exchange_Rate__mdt','CTBR_Units', 'CTBR Units',previousRateMap);
            }
            if(exRates.Name == 'CTBR Blue Edge'){
                currentRateMap.put('Current_Rate__c', exRates.CTBR_Current_Rate__c);
                ExchangeRateMetadataUtil.updateCustomMetadata('CTBR_Exchange_Rate__mdt','Blue_Edge', 'Blue Edge',currentRateMap);
                previousRateMap.put('Yesterday_Rate__c', exRates.CTBR_Previous_Rate__c);
                ExchangeRateMetadataUtil.updateCustomMetadata('CTBR_Exchange_Rate__mdt','Blue_Edge', 'Blue Edge',previousRateMap);
            }
        }*/
        ctbrExchangeRateTriggerHandler.afterUpdate(Trigger.new,Trigger.newMap,Trigger.oldMap);
    }
    if(trigger.isbefore && trigger.isupdate){
        for(Exchange_Rate__c exch : trigger.new){
            if(exch.CTBR_Current_Rate__c !=null && Trigger.oldMap.get(exch.id).CTBR_Current_Rate__c !=exch.CTBR_Current_Rate__c){
                exch.CTBR_Previous_Rate__c = Trigger.oldMap.get(exch.id).CTBR_Current_Rate__c;
            }
        }
    }
}