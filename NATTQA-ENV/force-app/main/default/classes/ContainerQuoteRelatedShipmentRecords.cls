/********************************************************************************************************
* @author         Deloitte
* @description    An ContainerQuoteRelatedShipmentRecords class is created for Fetching the Shipment_Schedule records for given Quote Number.
* @date           07/12/2022 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Deloitte               07/12/2022                                   Initial version
*********************************************************************************************************/

public Inherited Sharing class ContainerQuoteRelatedShipmentRecords {
    public Id quoteId {get;set;}
   	public List<Shipment_Schedule__c> getShipmentRecords() {
        // return null or empty list if the source quote Id is null
        if(String.isEmpty(quoteId)) {
            return null;
        }
        try {
            List<Shipment_Schedule__c> shipmentRecords = [SELECT CONTAINER_Qty__c, CONTAINER_WeekOf__c, CONTAINER_Destination__c, CONTAINER_Destination__r.Name FROM Shipment_Schedule__c
                where CONTAINER_Quote_Number__c=:quoteId WITH SECURITY_ENFORCED];
                 // Return list if there are records, or else return null or empty list
                if(!shipmentRecords.isEmpty()) {
                    return shipmentRecords;
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