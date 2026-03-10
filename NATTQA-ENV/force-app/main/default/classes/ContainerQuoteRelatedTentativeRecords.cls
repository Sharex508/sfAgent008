/********************************************************************************************************
* @author         Deloitte
* @description    An ContainerQuoteRelatedTentativeRecords class is created for Fetching the Tentative_Production_Schedule records for given Quote Number.
* @date           07/06/2022 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Deloitte               07/06/2022                                   Initial version
*********************************************************************************************************/

public Inherited Sharing class ContainerQuoteRelatedTentativeRecords {
    public Id quoteId {get;set;}
   	public List<CONTAINER_Tentative_Production_Schedule__c> gettentativeRecords() {
        // return null or empty list if the source quote Id is null
        if(String.isEmpty(quoteId)) {
            return null;
        }
        try {
            List<CONTAINER_Tentative_Production_Schedule__c> tentativeRecords = [SELECT CONTAINER_TentativeProductionSchd_Qty__c,CONTAINER_Week_Of__c,CONTAINER_Factory__c,CONTAINER_TentativeProdSchd_Job__c FROM CONTAINER_Tentative_Production_Schedule__c
                where CONTAINER_Quote_Number__c=:quoteId WITH SECURITY_ENFORCED];
                 // Return list if there are records, or else return null or empty list
                if(!tentativeRecords.isEmpty()) {
                    return tentativeRecords;
                } 
                else {
                    return null;
                }
        }
    	catch(QueryException ex) {
            return null;
    	}
    }
}