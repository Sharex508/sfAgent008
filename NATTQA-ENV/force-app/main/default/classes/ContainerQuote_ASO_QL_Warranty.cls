/********************************************************************************************************
* @author         Deloitte
* @description    An ContainerQuote_ASO_QL_Warranty class is created for Fetching the QuoteLine warranty records for given Quote Number.
* @date           07/22/2022 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Deloitte               07/22/2022                                   Initial version
*********************************************************************************************************/
public WITHOUT SHARING class ContainerQuote_ASO_QL_Warranty {
	 public Id quoteId {get;set;}
   	public List<SBQQ__QuoteLine__c> getwarrantyRecords() {
        // return null or empty list if the source quote Id is null
        if(String.isEmpty(quoteId)) {
            return null;
        }
        try {
            List<SBQQ__QuoteLine__c> warrantyRecords = [SELECT CONTAINER_Feature__c,CONTAINER_Warranty_Years__c FROM SBQQ__QuoteLine__c WHERE CONTAINER_Category__c = 'Warranty' AND SBQQ__Quote__c =:quoteId WITH SECURITY_ENFORCED];
                 // Return list if there are records, or else return null or empty list
                if(!warrantyRecords.isEmpty()) {
                    return warrantyRecords;
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