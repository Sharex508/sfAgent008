@isTest(seeAllData = true)
public class ctbrUtility_Test {
    public static SBQQ__Quote__c quote;
    public static Order order;
    public static Account acc;
    
    static testmethod void setData() {
        acc = new Account();
        acc.Name = 'Test';
        insert acc;
        
        Recordtype recType = [select id,name,SobjectType from RecordType where name = 'CTBR Units Quote'];
        try{
            quote = new SBQQ__Quote__c();
        quote.SBQQ__Primary__c = true;
        quote.SBQQ__Status__c = 'Activated';
        quote.NATT_Quote_Request_Date__c = date.today();
        quote.NATT_Dealer_Comments__c = 'Test';
        quote.CTBR_Quote_Delivery_Date__c = date.today().addDays(1);
        quote.CTBR_Freight_Terms__c = 'COL';
        quote.NATT_Product_Family__c = 'Trailer';
        quote.recordtypeId = recType.Id;
  	    //quote.NATT_Shipment_Method__c = 'Best Way';
  	    //quote.SBQQ__Primary__c = true;
        quote.SBQQ__PaymentTerms__c = 'Net 31';
        quote.CTBR_Tax_Observation__c = 'tax';
        insert quote;
            system.debug('quote-->'+quote);
        } catch(Exception ex){
            system.debug('insidecatch');
            ctbrUtility.LogException(ex,'ctbrOrderInboundIntegration','getOrderandQuote');
        }
	}
}