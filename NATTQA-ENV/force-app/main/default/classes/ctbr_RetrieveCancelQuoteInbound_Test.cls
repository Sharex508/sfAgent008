@isTest
public class ctbr_RetrieveCancelQuoteInbound_Test {
    public static SBQQ__Quote__c quote;
    public static SBQQ__Quote__c quoteObj;
    
    @testSetup
    static void datasetup1() {
        
        Recordtype recType = [select id,name,SobjectType from RecordType where name = 'CTBR Units Quote'];
        quote = new SBQQ__Quote__c();
        quote.SBQQ__Status__c = 'Draft';
        quote.RecordTypeId = recType.Id;
        quote.NATT_Quote_Request_Date__c = date.today();
        quote.Sent_Cancelled_to_SAP__c	= false;//1/19
        quote.NATT_Dealer_Comments__c = 'Test';
        quote.CTBR_Quote_Delivery_Date__c = date.today().addDays(1);
        quote.CTBR_Freight_Terms__c = 'CIF';
      //  quote.NATT_Shipment_Method__c = 'OTH';
        quote.SBQQ__PaymentTerms__c = 'Net 15';
        quote.CTBR_Tax_Observation__c = 'tax'; 
        insert quote;
        
        quote.SBQQ__Status__c = 'Activated';
        update quote;
        
        quote.SBQQ__Status__c = 'Canceled';
        update quote;
    }
    
    static void datasetup2() {
        quoteObj = new SBQQ__Quote__c();
        quoteObj.SBQQ__Status__c = 'Draft';
        quoteObj.NATT_Quote_Request_Date__c = date.today();
        quoteObj.NATT_Dealer_Comments__c = 'Test';
        quoteObj.CTBR_Quote_Delivery_Date__c = date.today().addDays(1);
        quoteObj.CTBR_Freight_Terms__c = 'CIF';
     //   quoteObj.NATT_Shipment_Method__c = 'OTH';
        quoteObj.SBQQ__PaymentTerms__c = 'Net 15';
        quoteobj.Sent_Cancelled_to_SAP__c	= false;//1/19
        quoteObj.CTBR_Tax_Observation__c = 'tax'; 
        insert quoteObj;
        
        quoteObj.SBQQ__Status__c = 'Activated';
        update quoteObj;
    }
    
    static testmethod void quoteData() {
        datasetup1();
        try{
            ctbr_RetrieveCancelQuoteInbound.getQuoteAndQuoteLineItems();
        }catch (Exception ex) {
            System.assertEquals('expected text', ex.getMessage());
        }        
    } 
}