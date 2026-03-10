/*Author: LTI
* Created Date: 13th October 2022
* Class Name: ctbr_RetrieveCancelQuoteInbound
* Description: This class is used to retrieve CTBR Units Cancelled quote from Salesforce
*/
@RestResource(urlMapping='/queryCancelQuote/*')
global without sharing class ctbr_RetrieveCancelQuoteInbound {
 
    // this method is used to fetch all the Cancelled CTBR quote records requested from SAP
    @HttpGet
    global static List<quoteWrapper> getQuoteAndQuoteLineItems() {
        try{
            List<SBQQ__Quote__c> quoteAndQuoteLineItemsLst = new List<SBQQ__Quote__c>();
            List<quoteWrapper> cancelledQuoteWrapperLst = new List<quoteWrapper>();
            //Only quote information needs to be sent, quote lines need not be sent. 
            for(SBQQ__Quote__c quoteObj : [SELECT id,recordtype.name,SBQQ__Status__c,name FROM SBQQ__Quote__c 
                                           WHERE recordtype.name = 'CTBR Units Quote'
                                           AND SBQQ__Status__c = 'Canceled' AND Sent_Cancelled_to_SAP__c = FALSE]) //1/19 corrected the flag to Sent_Cancelled_to_SAP__c
            {
                           quoteWrapper quoteWrapperObj = new quoteWrapper();
                           quoteWrapperObj.name = quoteObj.name;
                           quoteWrapperObj.status = quoteObj.SBQQ__Status__c;
                           quoteWrapperObj.quoteExternalId = quoteObj.id;
                           //    quoteWrapperObj.quoteline = storeQuoteLine(quoteObj.SBQQ__LineItems__r);
                           quoteobj.Sent_Cancelled_to_SAP__c = true;//17/10 this avoids resending of Cancelled quotes to SAP
                           // in the successive requests to Salesforce.
                           cancelledQuoteWrapperLst.add(quoteWrapperObj);
                           quoteAndQuoteLineItemsLst.add(quoteobj);//17/10
             }
                                          
            if(!quoteAndQuoteLineItemsLst.isempty())
            {	update quoteAndQuoteLineItemsLst;//17/10 
            }
            
            return cancelledQuoteWrapperLst;
        }catch(Exception ex){
            ctbrUtility.LogException(ex, 'ctbrRetrieveCancelQuoteIntegration', 'getQuoteAndQuoteLineItems');
            return null;
        }
    }
    
    //this method is used to store quoteLineItems in the quoteWrapperObj.. not required..
   /* public static List<quoteLineWrapper> storeQuoteLine(List<SBQQ__QuoteLine__c> lstQuoteLine) {
        
        List<quoteLineWrapper> quoteLineList = new List<quoteLineWrapper>();
        
        for(SBQQ__QuoteLine__c  quoteLineObj: lstQuoteLine){
            quoteLineWrapper quoteLineWrapperObj = new quoteLineWrapper();
            quoteLineWrapperObj.name = quoteLineObj.name;
            quoteLineWrapperObj.discount = quoteLineObj.SBQQ__Discount__c;
            quoteLineWrapperObj.componentCost = quoteLineObj.SBQQ__ComponentCost__c;
            quoteLineWrapperObj.quoteLineExternalId = quoteLineObj.id;
            quoteLineList.add(quoteLineWrapperObj);
        }
        return quoteLineList;   
    }*/
    
    global class quoteWrapper {
    //    public List<quoteLineWrapper> quoteline;
        public String name;
        public String status;
        public String quoteExternalId;
    }
    
    global class quoteLineWrapper {
        public String name;
        public double discount;
        public double componentCost;
        public String quoteLineExternalId;
    }
    
    global class ResponseSummary {
        //List of custom attributes that we want to check the status of the org
         
    }
}