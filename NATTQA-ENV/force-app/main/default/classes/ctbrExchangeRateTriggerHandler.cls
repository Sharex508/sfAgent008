public class ctbrExchangeRateTriggerHandler {
    //Created : Tejas Hatalkar,11/11/2022 to update Previous Rate with old value of Current Rate, invoke the CustomMetadata Utility.
	public static void afterUpdate(List<Exchange_Rate__c> exchNewList,Map<Id,Exchange_Rate__c> newExchMap,Map<Id,Exchange_Rate__c> oldExchMap){
    	if(!exchNewList.isEmpty() && !newexchMap.isEmpty() && !oldexchMap.isempty() ){
            System.debug('Inside ExchRate Trigger');
            Map<String, Object> currentRateMap = new Map<String, Object>();
            Map<String, Object> previousRateMap = new Map<String, Object>();
            Set<Id> ExchRateIds = new Set<Id>();
            for(Exchange_Rate__c exch : exchNewList){
            	System.debug('Old map value'+oldexchMap.get(exch.id).CTBR_Current_Rate__c);
            	System.debug('New Map value'+newexchMap.get(exch.id).CTBR_Current_Rate__c);
        		if(oldexchMap.get(exch.id).CTBR_Current_Rate__c != newexchMap.get(exch.id).CTBR_Current_Rate__c && newexchMap.get(exch.id).CTBR_Current_Rate__c !=null){
                    if(exch.Name == 'CTBR Units' || exch.Name == 'CTBR BlueEdge'){
                        System.debug('Inside exch Rate Trigger Handler for CTBR Units');
                        ExchRateIds.add(exch.id);
                        //currentRateMap.put('Current_Rate__c', exch.CTBR_Current_Rate__c);
                        //ExchangeRateMetadataUtil.updateCustomMetadata('CTBR_Exchange_Rate__mdt','CTBR_Units', 'CTBR Units',currentRateMap);
                        //previousRateMap.put('Yesterday_Rate__c', exch.CTBR_Previous_Rate__c);
                        //ExchangeRateMetadataUtil.updateCustomMetadata('CTBR_Exchange_Rate__mdt','CTBR_Units', 'CTBR Units',previousRateMap);
                    }
                    
                }
    		}
            if(!exchrateids.isempty()){
                ctbrExchangeRateMetadataUtil.updateCustomMetadataFuture(exchrateIds);
            }
    	}
	}
}