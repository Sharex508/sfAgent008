/**
* @File Name : NATT_OrderedQuoteDetails.cls
* @Description : Class created to fetch order details and amount of recent order from a Quote Detail page
* @Created By : Rajasekharreddy Kotella
* @created On : April 4, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | April 4, 2025 |   | Initial Version
**/

public class NATT_OrderedQuoteDetails {
	
    @AuraEnabled(cacheable=true)
    public static Order getOrderDetails(String quoteId) {
        Order orderDetails;
        
        List<SBQQ__Quote__c> quoteList = [
            SELECT Id, NATT_End_Customer__c, NATT_Unit__c, SBQQ__Ordered__c, SBQQ__Account__c, SBQQ__Account__r.Name
            FROM SBQQ__Quote__c
            WHERE Id = :quoteId
            AND NATT_Quote_Record_Type_Developer_Name__c like '%NATT_Units_Quote%'
        ];
        
        if (!quoteList.isEmpty()) {
            SBQQ__Quote__c quoteDetails = quoteList[0];
            
            List<Order> orderList = [
                SELECT Id, SBQQ__Quote__c,NATT_Requested_Ship_Date__c, OrderNumber,SBQQ__Quote__r.NATT_Total_Per_Unit_Without_EMCC_New__c,SBQQ__Quote__r.NATT_Configured_Unit_Code__c,SBQQ__Quote__r.NATT_Unit__c, NATT_Unit__c, NATT_Net_Amount__c, CreatedDate 
                FROM Order  
                WHERE RecordType.Name like '%NATT Unit%'
                AND SBQQ__Quote__r.NATT_End_Customer__c != null
                AND SBQQ__Quote__r.NATT_Unit__c = :quoteDetails.NATT_Unit__c 
                AND SBQQ__Quote__r.SBQQ__Account__c = :quoteDetails.SBQQ__Account__c
                AND SBQQ__Quote__r.NATT_End_Customer__c = :quoteDetails.NATT_End_Customer__c
                ORDER BY CreatedDate DESC  
                LIMIT 1
            ];
            
                if (!orderList.isEmpty()) {
                    orderDetails = orderList[0];
                }
        }
        
        return orderDetails; // will return null if nothing was found
    }
    
}