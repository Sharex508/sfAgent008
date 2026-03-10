/********************************************************************************************************
* @author         Deloitte
* @description    An ContainerQuoteASOTentativeRecords class is created for Fetching the Tentative_Production_Schedule records for given Quote Number.
* @date           07/06/2022 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Deloitte               07/19/2022                                   Initial version
*********************************************************************************************************/
public Inherited Sharing class ContainerQuoteASOTentativeRecords {
	 public Id quoteId {get;set;}
    Public List<CONTAINER_Tentative_Production_Schedule__c> tentativeRecords {get;set;}
    public String breakLine {get;set;}
   	public ContainerQuoteASOTentativeRecords() {
         quoteId  = ApexPages.currentPage().getParameters().get('qid');
        // return null or empty list if the source quote Id is null
        try {
                tentativeRecords = [SELECT CONTAINER_TentativeProductionSchd_Qty__c,CONTAINER_Week_Of__c,CONTAINER_Factory__c,CONTAINER_TentativeProdSchd_Job__c FROM CONTAINER_Tentative_Production_Schedule__c
                where CONTAINER_Quote_Number__c=:quoteId WITH SECURITY_ENFORCED];
            breakLine = '\r\n\r\n&nbsp;TENTATIVE PRODUCTION SCHEDULE';
        }
    	catch(QueryException ex) {
            
    	}
    }
}