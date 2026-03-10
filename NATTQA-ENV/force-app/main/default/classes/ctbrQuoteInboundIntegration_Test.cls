@isTest(seeAllData = true)
public class ctbrQuoteInboundIntegration_Test {
    public static SBQQ__Quote__c quote;
    public static SBQQ__QuoteLine__c quoteLine;
    public static Product2 prod;

    static void setData() {
        
        prod = new Product2();
        prod.Name = 'Test';
        prod.ProductCode = '0908777';
        insert prod;
        
        Recordtype recType = [select id,name,SobjectType from RecordType where name = 'CTBR Units Quote'];
        
        quote = new SBQQ__Quote__c();
        quote.SBQQ__Status__c = 'Approved';
        quote.NATT_Quote_Request_Date__c = date.today();
        quote.NATT_Dealer_Comments__c = 'Test';
        quote.CTBR_Quote_Delivery_Date__c = date.today().addDays(1);
        quote.CTBR_Freight_Terms__c = 'CIF';
        quote.NATT_Product_Family__c = 'Trailer';
        quote.recordtypeId = recType.Id;
        //quote.NATT_Shipment_Method__c = 'Best Way';
        quote.SBQQ__PaymentTerms__c = 'Net 31';
        quote.CTBR_Condicoes_comerciais__c='Credito (credit)';
        quote.CTBR_Tax_Observation__c = 'tax';
        insert quote;
        System.debug('Quote id is'+quote.id);

        quoteLine = new SBQQ__QuoteLine__c();
        quoteLine.SBQQ__Discount__c = 10;
        //quoteLine.SBQQ__ProductName__c = 'CITIMAX 280 12V R404a';
        quoteLine.SBQQ__Product__c = prod.id;
        quoteLine.CTBR_Purchase_Number_Optional__c = null;
        quoteLine.CTBR_Purchase_Number_U_IB_OrdemCompra__c = null;
        quoteLine.SBQQ__Quantity__c = 2;
        quoteLine.SBQQ__ListPrice__c = 100;
        quoteLine.SBQQ__NetPrice__c = 200;
        quoteLine.SBQQ__Quote__c = quote.id;
        quoteLine.SBQQ__AllowAssetRefund__c = false;
        quoteLine.SBQQ__Bundle__c = false;
        quoteLine.SBQQ__Bundled__c = false;
        quoteLine.SBQQ__CarryoverLine__c = false;
        quoteline.SBQQ__Quote__c = quote.id;
        try {
            insert quoteLine;
        } catch (Exception e) {
            e.getMessage();
        }
        
        

    }

    static testMethod void updateQuoteTest() {
        setData();
        SBQQ__Quote__c quoteObj = [SELECT id, recordtype.name, CTBR_Payment_Condition_Code__c, CTBR_Freight_Price__c, CTBR_Subtotal_ICMS__c, CTBR_Total_ICMS__c, CTBR_Total_ICMS_ST__c, CTBR_Total_IPI__c, CTBR_Total_Payable__c, CTBR_Fixed_Payment__c, CTBR_Has_Global_Price_List__c, CTBR_Global_Price_List_Code__c, CTBR_Taxation__c FROM SBQQ__Quote__c where id =: quote.id];
        quoteObj.CTBR_Payment_Condition_Code__c = 780;
        quoteObj.CTBR_Freight_Price__c = 1000;
        quoteObj.CTBR_Subtotal_ICMS__c = 8000;
        quoteObj.CTBR_Total_ICMS__c = 670;
        quoteObj.CTBR_Total_ICMS_ST__c = 6098;
        quoteObj.CTBR_Total_IPI__c = 1093;
        quoteObj.CTBR_Total_Payable__c = 4000;
        quoteObj.CTBR_Has_Global_Price_List__c = False;
        quoteObj.CTBR_Fixed_Payment__c = False;
        quoteObj.CTBR_Global_Price_List_Code__c = 3234;
        quoteObj.CTBR_Taxation__c = 3243.00;
        update quoteObj;
    }

    static testMethod void testgetQuoteAndQuoteLineItems() {
        setData();
        SBQQ__Quote__c quo = [SELECT Id, SBQQ__Status__c, CTBR_Tax_Observation__c, NATT_Dealer_Comments__c, SBQQ__PaymentTerms__c, NATT_Quote_Request_Date__c, CTBR_Freight_Terms__c, NATT_Shipment_Method__c FROM SBQQ__Quote__c where id =: quote.id];
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/retrieveQuotes/' + quo.Id;
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        ctbrQuoteInboundIntegration.getQuoteAndQuoteLineItems();
        Test.stopTest();
        system.assertEquals(quo.SBQQ__Status__c, 'Approved');
        system.assertEquals(quo.NATT_Dealer_Comments__c, 'Test');
        system.assertEquals(quo.NATT_Quote_Request_Date__c, date.today());
        system.assertEquals(quo.CTBR_Freight_Terms__c, 'CIF');
        system.assertEquals(quo.SBQQ__PaymentTerms__c, 'Net 31');
        //system.assertEquals(quo.NATT_Shipment_Method__c, 'Best Way');
        system.assertEquals(quo.CTBR_Tax_Observation__c, 'tax');
    }

    static testMethod void testPut() {
        setData();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/retrieveQuotes/';
        req.httpMethod = 'PUT';
        RestContext.request = req;
        RestContext.response = res;
        SBQQ__Quote__c qcc = [SELECT Id, CTBR_Payment_Condition_Code__c, CTBR_Freight_Price__c FROM SBQQ__Quote__c where id =: quote.id];
        try {
            ctbrQuoteInboundIntegration.updateQuote(null);
        } catch (Exception e) {}
        try {
            ctbrQuoteInboundIntegration.getQuoteAndQuoteLineItems();
        } catch (Exception e) {}
    }
    
    static testMethod void testquoteWrapper() {
        List<ctbrQuoteInboundIntegration.quoteWrapper> quoteWrap = new List<ctbrQuoteInboundIntegration.quoteWrapper>();
        List<ctbrQuoteInboundIntegration.quoteLineWrapper> quoteLWrap = new List<ctbrQuoteInboundIntegration.quoteLineWrapper>();
        
        ctbrQuoteInboundIntegration.quoteLineWrapper cL = new ctbrQuoteInboundIntegration.quoteLineWrapper();
        cL.name = 'TestL';
        cL.discount = 10.20;
        cL.componentCost = 12.12;
        //cL.quoteLineExternalId = '12';
        cL.quantity = '1.00';
        cL.product = '';
        //cL.productCode =
        //cL.purchaseNumberOptional =
        cL.purchaseNumberUIB =
        cL.unitMeasurement =
        cL.listPrice =
        cL.netPrice =
        cL.NCM = 'CTBR_NCM__c';
        cL.totalPrice = '14.22';
        cL.priceStTax = '14.22';
        cL.percentageIpiTax = '14.22';
        cL.priceIpiTax = '14.33';
        cL.netTotalPlusPriceIpiTax = '14.33';
        cL.exchangeTaxOfTheQuoteCreation = '14.33';
        cL.actualUnitPrice = '14.33';
        cL.materialGroupPercent ='14.22';
        cL.freightPercentOfGlobalParameter = '14.22';
        cL.customFeesPercentOfGlobalParameter =  '14.22';
        cL.netValueInDollar = '12.22';
        cL.realNetValue = '12.22';
        cL.totalTax = '12.22';
        cL.icmsTax = '12.22';
        cL.pisTax ='12.22';
        cL.cofinsTax = '12.22';
        cL.discountPercentInCustomerGroup =  '14.22';
        cL.itemQuantityAvailableForSales = '11';
        quoteLWrap.add(cL);
        
        ctbrQuoteInboundIntegration.quoteWrapper c = new ctbrQuoteInboundIntegration.quoteWrapper();    
        c.quoteline = quoteLWrap;
        c.name = 'Test';
        c.status = 'Approved';
        c.SenttoSAP = false;
        c.requestDate = '12-12-12';
        c.dealerComments = '12-12-12';
        c.paymentTerms = 'Net 31';
        c.freightTerms = 'Net 31';
        c.shipmentMethod = 'Best Way';
        c.taxObservation = 'tax';
        c.salesRep = userinfo.getUserId();
        c.paymentCCode = '11';
        c.freightPrice = '11.5666';
        c.subICMS = '11.5666';
        c.totalICMS = '11.5666';
        c.totalIPI = '11.5666';
        c.totalICMSST = '11.5666';
        c.totalPayable = '11.5666';
        c.fixedPayment = 'true';
        c.hasGlobalPriceList = 'true';
        c.globalPriceListCode = '11.0';
        c.taxation  = 'tax';
        c.taxation  = '11.5666';
        quoteWrap.add(c);
        
        ctbrQuoteInboundIntegration.updateQuote(quoteWrap);
        
    }
}