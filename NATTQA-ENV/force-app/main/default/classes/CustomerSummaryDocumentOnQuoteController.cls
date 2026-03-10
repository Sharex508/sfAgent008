/*****************************************************************************************************************************************************************************************
* NAME         : CustomerSummaryDocumentOnQuoteController
* DESCRIPTION  : Class for customer summary document download
*                    
* @AUTHOR :  Utkarsh Mishra 
* @DATE   :   07/10/2023
* @testclasses :CustomerSummaryControllerTest
*
* MODIFICATION LOG:  
* ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
* DEVELOPER                DATE                DESCRIPTION 
* --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Utkarsh Mishra         10-July-2023          CCRN-79 : CPQ - P1.2d - Generate Customer Summary Document
****************************************************************************************************************************************************************************************/ 
/**
* @description - CustomerSummaryDocumentOnQuoteController class
*/
public class CustomerSummaryDocumentOnQuoteController {
    public SBQQ__Quote__c quoteList;
    /**
    * @description -  gets/sets the record id
    */
    public String recordId { get; set; }
    /**
    * @description - gets/sets the object name
    */
    public String objAPIName { get; set; }
    /** 
    * @description - gets the data from wrapper and fills the value on the vf page 
    */  
    public static CustomerSummaryController.DataOutputWrapper dataOutput { get; set; }
    /** 
    * @description - this is a constructor
    */ 
    public CustomerSummaryDocumentOnQuoteController(){
        recordId = ApexPages.currentPage().getParameters().get('id');
        objAPIName = ApexPages.currentPage().getParameters().get('objAPI');

        if(objAPIName == 'SBQQ__Quote__c') {
            dataOutput = (CustomerSummaryController.DataOutputWrapper)JSON.deserialize(CustomerSummaryController.getQuoteRecordDetails(recordId),CustomerSummaryController.DataOutputWrapper.class);
        } else if(objAPIName  == 'Order' ) {
            dataOutput = (CustomerSummaryController.DataOutputWrapper)JSON.deserialize(CustomerSummaryController.getOrderRecordDetails(recordId),CustomerSummaryController.DataOutputWrapper.class);
        } 
    }
   
}