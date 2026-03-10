/*Author: LTI
* Created Date: 6th October 2022
* Class Name: ctbrQuoteInboundIntegration
* Description: This class is used to retrieve/update CTBR Units quotes and quoteLineItems from SAP
*/
@RestResource(urlMapping='/retrieveQuotes/*')
global without sharing class ctbrQuoteInboundIntegration {
 
    // this method is used to fetch all the CTBR quote and qutoeLineItems records requested from SAP
    @HttpGet
    global static List<GetQuoteWrapper> getQuoteAndQuoteLineItems() {
        try{
            List<SBQQ__Quote__c> quoteAndQuoteLineItemsLst = new List<SBQQ__Quote__c>();
            List<GetQuoteWrapper> apprrovedQuoteWrapperLst = new List<GetQuoteWrapper>();
            
            for(SBQQ__Quote__c quoteObj : [SELECT id,recordtype.name,CTBR_Warehouse__c,CTBR_Condicoes_comerciais__c,CTBR_JDE_Shipping_Address_Id__c,CTBR_JDE_Billing_Address_Id__c,Sent_to_SAP__c,SBQQ__Status__c,CTBR_Quote_Delivery_Date__c,name,CTBR_Freight_Terms__c,CTBR_Shipment_Method__c,CTBR_Shipment_Company__c,NATT_Dealer_Comments__c,SBQQ__PaymentTerms__c,NATT_Quote_Request_Date__c,CTBR_Tax_Observation__c,SBQQ__SalesRep__c,CTBR_Payment_Condition_Code__c,CTBR_Freight_Price__c,CTBR_Subtotal_ICMS__c,CTBR_Total_ICMS__c,CTBR_Total_ICMS_ST__c,CTBR_Total_IPI__c,CTBR_Total_Payable__c,CTBR_Fixed_Payment__c,CTBR_Has_Global_Price_List__c,CTBR_Global_Price_List_Code__c,CTBR_Taxation__c,
                                           (Select Id,name,SBQQ__Discount__c,SBQQ__ComponentCost__c,SBQQ__Quantity__c,SBQQ__NetPrice__c,SBQQ__ListPrice__c,SBQQ__Product__c,CTBR_Purchase_Number_Optional__c,CTBR_Unit_of_Measurement__c,CTBR_Purchase_Number_U_IB_OrdemCompra__c,SBQQ__ProductCode__c,CTBR_ItemQuantityAvailableForSales__c,CTBR_DiscountPercentInCustomerGroup__c,CTBR_CofinsTax__c,CTBR_PisTax__c,CTBR_IcmsTax__c,CTBR_TotalTax__c,CTBR_RealNetValue__c,CTBR_NetValueInDollar__c,CTBR_CustomFeesPercentOfGlobalParameter__c,
                                            CTBR_FreightPercentOfGlobalParameter__c,CTBR_MaterialGroupPercent__c,CTBR_Actual_Unit_Price__c,CTBR_ExchangeTaxOfTheQuoteCreation__c,CTBR_NetTotalPlusPriceIpiTax__c,CTBR_PriceIpiTax__c,CTBR_PercentageIpiTax__c,CTBR_PriceStTax__c,CTBR_Total_Price__c,CTBR_NCM__c
                                            FROM SBQQ__LineItems__r where SBQQ__ProductCode__c !=null) FROM SBQQ__Quote__c //added where SBQQ_Productcode__c !=null on 1/6/23
                                           WHERE recordtype.name = 'CTBR Units Quote'
                                           AND SBQQ__Status__c = 'Approved' AND Sent_to_SAP__c = FALSE 
                                          ]) {
                                           //This assumes that Quote Line is always present under a CTBR Quote
                                               if(!quoteObj.SBQQ__LineItems__r.isEmpty()){ 
                                                   GetQuoteWrapper quoteWrapperObj = new GetQuoteWrapper();
                                                   quoteWrapperObj.name = quoteObj.name;
                                                   quoteWrapperObj.wareHouse = quoteObj.CTBR_Warehouse__c;//1/11/23
                                                   quoteWrapperObj.BillToLocation = quoteobj.CTBR_JDE_Billing_Address_Id__c;//5/12
                                                   quoteWrapperObj.ShipToLocation = quoteobj.CTBR_JDE_Shipping_Address_Id__c;//8/12
                                                   quoteWrapperObj.salesrep = quoteobj.SBQQ__SalesRep__c;//9/11
                                                   quoteWrapperObj.status = quoteObj.SBQQ__Status__c;
                                                   quoteWrapperObj.requestDate = string.valueOf(quoteObj.NATT_Quote_Request_Date__c);
                                                   quoteWrapperObj.dealerComments = quoteObj.NATT_Dealer_Comments__c;
                                                   quoteWrapperObj.quoteDeliveryDate = quoteobj.CTBR_Quote_Delivery_Date__c;
                                                   quoteWrapperObj.freightTerms = quoteObj.CTBR_Freight_Terms__c;
                                                   quoteWrapperObj.shipmentMethod = quoteObj.CTBR_Shipment_Method__c;
                                                   quoteWrapperObj.shipmentCompany = quoteobj.CTBR_Shipment_Company__c;//Added 1/6/23
                                                   quoteWrapperObj.paymentTerms = quoteObj.SBQQ__PaymentTerms__c;
                                                   quoteWrapperObj.taxObservation = quoteObj.CTBR_Tax_Observation__c;
                                                   quoteWrapperObj.quoteExternalId = quoteObj.id;
                                                   quoteObj.Sent_to_SAP__c = true;//13/10
                                                   quoteWrapperObj.quoteline = storeQuoteLine(quoteObj.SBQQ__LineItems__r);
                                                   quoteWrapperObj.commercialconditions=quoteObj.CTBR_Condicoes_comerciais__c;
                                                   apprrovedQuoteWrapperLst.add(quoteWrapperObj);
                                                   quoteAndQuoteLineItemsLst.add(quoteobj);//13/0
                                              }
                                           }
            if(!quoteAndQuoteLineItemsLst.isempty())
            {   update quoteAndQuoteLineItemsLst;//13/10 
            }
            
            return apprrovedQuoteWrapperLst;
        }catch(Exception ex){
            ctbrUtility.LogException(ex, 'ctbrQuoteInboundIntegration', 'getQuoteAndQuoteLineItems');
            return null;
        }
    }
    
    //this method is used to store quoteLineItems in the quoteWrapperObj
    public static List<GetquoteLineWrapper> storeQuoteLine(List<SBQQ__QuoteLine__c> lstQuoteLine) {
        
        List<GetquoteLineWrapper> quoteLineList = new List<GetquoteLineWrapper>();
        
        for(SBQQ__QuoteLine__c  quoteLineObj: lstQuoteLine){
            GetquoteLineWrapper quoteLineWrapperObj = new GetquoteLineWrapper();
            quoteLineWrapperObj.name = quoteLineObj.name;
            quoteLineWrapperObj.Addtionaldiscount = quoteLineObj.SBQQ__Discount__c;//activated o 1/6/23
            quoteLineWrapperObj.product = quoteLineObj.SBQQ__Product__c;
            quoteLineWrapperObj.productCode = quoteLineObj.SBQQ__ProductCode__c;
            quoteLineWrapperObj.purchaseNumberOptional = quoteLineObj.CTBR_Purchase_Number_Optional__c;
            quoteLineWrapperObj.purchaseNumberUIB = quoteLineObj.CTBR_Purchase_Number_U_IB_OrdemCompra__c;
            quoteLineWrapperObj.unitMeasurement = quoteLineObj.CTBR_Unit_of_Measurement__c;
        //    quoteLineWrapperObj.componentCost = quoteLineObj.SBQQ__ComponentCost__c;
            quoteLineWrapperObj.quantity = String.ValueOf(quoteLineObj.SBQQ__Quantity__c);
            quoteLineWrapperObj.listPrice = String.ValueOf(quoteLineObj.SBQQ__ListPrice__c);
      //    quoteLineWrapperObj.netPrice = String.ValueOf(quoteLineObj.SBQQ__NetPrice__c); //commenting as requested in UAT 1/5/2023
                  quoteLineWrapperObj.quoteLineExternalId = quoteLineObj.id;
            quoteLineList.add(quoteLineWrapperObj);
        }
        return quoteLineList;   
    }
    
    // this method is used to update all the CTBR quote and quoteLineItems records sent from SAP
    @HttpPut
    global static String updateQuote(List<quoteWrapper> sapQuoteLst) {
        try{ 
            List<SBQQ__Quote__c> quoteLst = new List<SBQQ__Quote__c>();
            List<SBQQ__QuoteLine__c> quoteLineItemsLst = new List<SBQQ__QuoteLine__c>();
            if(sapquoteLst.size() > 300)
            {
                return 'Too many quotes in Request: ' +sapquoteLst.size()+', please limit the Batch size to 300 quotes';
            }
            /*Map<id, quoteWrapper> quoteMap = new Map<id, quoteWrapper>();
            
            for(quoteWrapper quoteWrapperObj : sapQuoteLst){
                quoteMap.put(quoteWrapperObj.quoteExternalId, quoteWrapperObj);
            }*/
            
            for(quoteWrapper quoteWrapperObj : sapQuoteLst) {
                SBQQ__Quote__c quoteToUpdate = new SBQQ__Quote__c();
                if(quoteWrapperObj.status != null) 
                {   
                    quoteToUpdate.SBQQ__Status__c = quoteWrapperObj.status;
                }
                if(quoteWrapperObj.salesRep !=null) 
                {
                    quoteToUpdate.SBQQ__SalesRep__c = quoteWrapperObj.salesRep;
                }
                if(quoteWrapperObj.SAPQuotationCode !=null) //9/11
                {
                    quotetoUpdate.CTBR_Quotation_Code_SAP__c = quoteWrapperObj.SAPQuotationCode; 
                }
                if(quoteWrapperObj.SAPQuoteId !=null) //9/11
                {
                    quotetoUpdate.CTBR_SAP_Quote_ID__c = quoteWrapperObj.SAPQuoteId; 
                }
                if(quoteWrapperObj.paymentCCode !=null)
                {  
                    quoteToUpdate.CTBR_Payment_Condition_Code__c = Decimal.valueOf(quoteWrapperObj.paymentCCode); 
                } 
                if(quoteWrapperObj.freightPrice != null)
                {  
                    quoteToUpdate.CTBR_Freight_Price__c = Decimal.valueOf(quoteWrapperObj.freightPrice);
                } 
                if(quoteWrapperObj.subICMS != null)
                {
                    quoteToUpdate.CTBR_Subtotal_ICMS__c = Decimal.valueOf(quoteWrapperObj.subICMS);
                } 
                if(quoteWrapperObj.totalICMS != null)
                {
                    quoteToUpdate.CTBR_Total_ICMS__c = Decimal.valueOf(quoteWrapperObj.totalICMS);
                }
                if(quoteWrapperObj.totalICMSST != null)
                {
                    quoteToUpdate.CTBR_Total_ICMS_ST__c = Decimal.valueOf(quoteWrapperObj.totalICMSST);
                }
                if(quoteWrapperObj.totalIPI != null)
                {
                    quoteToUpdate.CTBR_Total_IPI__c = Decimal.valueOf(quoteWrapperObj.totalIPI);
                }
                if(quoteWrapperObj.totalPayable != null)
                {
                    quoteToUpdate.CTBR_Total_Payable__c = Decimal.valueOf(quoteWrapperObj.totalPayable);
                } 
                if(quoteWrapperObj.fixedPayment != null)
                {
                    quoteToUpdate.CTBR_Fixed_Payment__c = Boolean.valueOf(quoteWrapperObj.fixedPayment);
                } 
                if(quoteWrapperObj.hasGlobalPriceList != null)
                {
                quoteToUpdate.CTBR_Has_Global_Price_List__c = Boolean.valueOf(quoteWrapperObj.hasGlobalPriceList);
                } 
                 if(quoteWrapperObj.globalPriceListCode != null)
                {
                quoteToUpdate.CTBR_Global_Price_List_Code__c = Decimal.valueOf(quoteWrapperObj.globalPriceListCode);
                }
                 if(quoteWrapperObj.taxation != null)
                {
                quoteToUpdate.CTBR_Taxation__c = Decimal.valueOf(quoteWrapperObj.taxation);
                }
                quoteToUpdate.id = quoteWrapperObj.quoteExternalId;
                
                for(quoteLineWrapper quoteLineWrapperObj : quoteWrapperObj.quoteline) {
                    SBQQ__QuoteLine__c quoteLineToUpdate = new SBQQ__QuoteLine__c();
                    if(quoteLineWrapperObj.discount !=null)
                    {   
                        quoteLineToUpdate.SBQQ__Discount__c = quoteLineWrapperObj.discount;
                    }
                   
                    if(quoteLineWrapperObj.componentCost !=null)
                    {
                        quoteLineToUpdate.SBQQ__ComponentCost__c = quoteLineWrapperObj.componentCost;
                    }
                    if(quoteLineWrapperObj.NCM != null)
                    {
                        quoteLineToUpdate.CTBR_NCM__c  = quoteLineWrapperObj.NCM;
                    }
                   // quoteLineToUpdate.CTBR_NCM__c = quoteLineWrapperObj.NCM;
                    if(quoteLineWrapperObj.quantity != null)
                    {
                        quoteLineToUpdate.SBQQ__Quantity__c  = Decimal.valueOf(quoteLineWrapperObj.quantity);
                    }
                    if(quoteLineWrapperObj.totalPrice != null)
                    {
                        quoteLineToUpdate.CTBR_Total_Price__c = Decimal.valueOf(quoteLineWrapperObj.totalPrice);
                    }
                    if(quoteLineWrapperObj.priceStTax != null)
                    {
                        quoteLineToUpdate.CTBR_PriceStTax__c = Decimal.valueOf(quoteLineWrapperObj.priceStTax);
                    }
                    if(quoteLineWrapperObj.percentageIpiTax != null)
                    {
                        quoteLineToUpdate.CTBR_PercentageIpiTax__c = Decimal.valueOf(quoteLineWrapperObj.percentageIpiTax);
                    }
                    if(quoteLineWrapperObj.priceIpiTax != null)
                    {
                        quoteLineToUpdate.CTBR_PriceIpiTax__c = Decimal.valueOf(quoteLineWrapperObj.priceIpiTax);
                    }
                    if(quoteLineWrapperObj.netTotalPlusPriceIpiTax != null)
                    {
                        quoteLineToUpdate.CTBR_NetTotalPlusPriceIpiTax__c = Decimal.valueOf(quoteLineWrapperObj.netTotalPlusPriceIpiTax);
                    }
                    if(quoteLineWrapperObj.exchangeTaxOfTheQuoteCreation != null)
                    {
                        quoteLineToUpdate.CTBR_ExchangeTaxOfTheQuoteCreation__c = Decimal.valueOf(quoteLineWrapperObj.exchangeTaxOfTheQuoteCreation);
                    }
                    if(quoteLineWrapperObj.actualUnitPrice != null)
                    {
                        quoteLineToUpdate.CTBR_Actual_Unit_Price__c = Decimal.valueOf(quoteLineWrapperObj.actualUnitPrice);
                    }
                    if(quoteLineWrapperObj.materialGroupPercent != null)
                    {
                        quoteLineToUpdate.CTBR_MaterialGroupPercent__c = Decimal.valueOf(quoteLineWrapperObj.materialGroupPercent);
                    }
                    if(quoteLineWrapperObj.freightPercentOfGlobalParameter != null)
                    {
                        quoteLineToUpdate.CTBR_FreightPercentOfGlobalParameter__c = Decimal.valueOf(quoteLineWrapperObj.freightPercentOfGlobalParameter);
                    }
                    if(quoteLineWrapperObj.customFeesPercentOfGlobalParameter != null)
                    {
                        quoteLineToUpdate.CTBR_CustomFeesPercentOfGlobalParameter__c = Decimal.valueOf(quoteLineWrapperObj.customFeesPercentOfGlobalParameter);
                    }
                    if(quoteLineWrapperObj.netValueInDollar != null)
                    {
                        quoteLineToUpdate.CTBR_NetValueInDollar__c = Decimal.valueOf(quoteLineWrapperObj.netValueInDollar);
                    }
                    if(quoteLineWrapperObj.realNetValue != null)
                    {
                        quoteLineToUpdate.CTBR_RealNetValue__c = Decimal.valueOf(quoteLineWrapperObj.realNetValue);
                    }
                    if(quoteLineWrapperObj.totalTax != null)
                    {
                        quoteLineToUpdate.CTBR_TotalTax__c = Decimal.valueOf(quoteLineWrapperObj.totalTax);
                    }
                    if(quoteLineWrapperObj.icmsTax != null)
                    {
                        quoteLineToUpdate.CTBR_IcmsTax__c = Decimal.valueOf(quoteLineWrapperObj.icmsTax);
                    }
                    if(quoteLineWrapperObj.pisTax != null)
                    {
                        quoteLineToUpdate.CTBR_PisTax__c = Decimal.valueOf(quoteLineWrapperObj.pisTax);
                    }
                    if(quoteLineWrapperObj.cofinsTax != null)
                    {
                        quoteLineToUpdate.CTBR_CofinsTax__c = Decimal.valueOf(quoteLineWrapperObj.cofinsTax);
                    }
                    if(quoteLineWrapperObj.discountPercentInCustomerGroup != null)
                    {
                        quoteLineToUpdate.CTBR_DiscountPercentInCustomerGroup__c = Decimal.valueOf(quoteLineWrapperObj.discountPercentInCustomerGroup);
                    }
                    if(quoteLineWrapperObj.itemQuantityAvailableForSales != null)
                    {
                        quoteLineToUpdate.CTBR_ItemQuantityAvailableForSales__c = Decimal.valueOf(quoteLineWrapperObj.itemQuantityAvailableForSales);
                    }
                    quoteLineToUpdate.id = quoteLineWrapperObj.quoteLineExternalId;
                    quoteLineItemsLst.add(quoteLineToUpdate);
                }
                quoteLst.add(quoteToUpdate);
            }            
            System.debug('resultLst&&&&!!');
            Database.SaveResult[] quoteResultLst = Database.update(quoteLst, false);
            Database.SaveResult[] quoteLineResultLst = Database.update(quoteLineItemsLst, false);
            System.debug('resultLst&&&&' + quoteResultLst);
            return 'Success';  
        }catch(Exception ex){
            ctbrUtility.LogException(ex, 'ctbrQuoteInboundIntegration', 'updateQuote');
           return 'Error in updating Quotes: '+ex.getMessage() + ' : ' +ex.getStackTraceString();
        }
    }
    
    global class quoteWrapper {
        public List<quoteLineWrapper> quoteline;
        public String name;
        public integer SAPQuotationCode;
        public integer SAPQuoteId;//passed from SAP.
        public String status;
        public boolean SenttoSAP;//13/10
        public String quoteExternalId;
        public String requestDate;
        public String dealerComments;
        public String paymentTerms;
        public String freightTerms;
        public String shipmentMethod;
        public String taxObservation;
        public String salesRep;
        public String paymentCCode;
        public String freightPrice;
        public String subICMS;
        public String totalICMS;
        public String totalIPI;
        public String totalICMSST;
        public String totalPayable;
        public String fixedPayment;
        public String hasGlobalPriceList;
        public String globalPriceListCode;
        public String taxation;
     }
    
    global class quoteLineWrapper {
        public String name;
        public double discount;
        public double componentCost;
        public String quoteLineExternalId;
        public String quantity;
        public String product;
        public String productCode;
        public String purchaseNumberOptional;
        public String purchaseNumberUIB;
        public String unitMeasurement;
        public String listPrice;
        public String netPrice;
        public String NCM;
        public String totalPrice;
        public String priceStTax;
        public String percentageIpiTax;
        public String priceIpiTax;
        public String netTotalPlusPriceIpiTax;
        public String exchangeTaxOfTheQuoteCreation;
        public String actualUnitPrice;
        public String materialGroupPercent;
        public String freightPercentOfGlobalParameter;
        public String customFeesPercentOfGlobalParameter;
        public String netValueInDollar;
        public String realNetValue;
        public String totalTax;
        public String icmsTax;
        public String pisTax;
        public String cofinsTax;
        public String discountPercentInCustomerGroup;
        public String itemQuantityAvailableForSales;
    }
    
    global class ResponseSummary {
        //List of custom attributes that we want to check the status of the org
         
    }
    //2/11 added 2 separate Wrapper classes for GET,to avoid extra fields sent in the Response.
    global class GetQuoteWrapper{
        public List<GetquoteLineWrapper> quoteline;
        public String name;
        public string BillToLocation; //added 5/12.returns JDE Address Id of Bill to location selected
        public string ShipToLocation;//added 8/12 returns JDE Address Id of Ship to location selected
        public String status;
      //  public boolean SenttoSAP;//13/10
        public String quoteExternalId;
        public date quoteDeliveryDate;
        public String shipmentMethod;
        public String shipmentCompany;// Added 1/6/23.
        public String taxObservation;
        public string freightTerms;
        public String salesRep;
        public string requestDate;
        public string dealerComments;
        public string paymentTerms;
        public string wareHouse;
        public String commercialconditions;//23/10/2025

    }
    global class GetquoteLineWrapper {
        public String name;
        public double addtionalDiscount; //activated on 1/6/23
     //   public double componentCost;
        public String quoteLineExternalId;
        public String quantity;
        public String product;
        public String productCode;
        public String listPrice;
 //       public String netPrice; commenting as requested in UAT 1/5/23.
        public String purchaseNumberOptional;
        public String purchaseNumberUIB;
        public String unitMeasurement;
    }
}