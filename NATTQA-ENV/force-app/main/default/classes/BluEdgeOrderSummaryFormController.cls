public class BluEdgeOrderSummaryFormController{
    public Order order {get;set;}
    public Boolean dealerCopy {get;set;}
    public String quoteID {get;set;}
    public String quoteDate {get;set;}
    public String quoteExpires {get;set;}
    public String customerName {get;set;}
    public String salesRepName {get;set;}
    public String dealerName {get;set;}
    public String billingStreet {get;set;}
    public String billingCity {get;set;}
    public String billingState {get;set;}
    public String billingPostalCode {get;set;}
    public String billingCountry {get;set;}
    public String dealerPhone {get;set;}
    public String unitModel {get;set;}
    public Double pricePerUnit {get;set;}
    public Double pricePerHour {get;set;}
    public String logoBluEdge {get;set;}
    public String typeBluEdge {get;set;}
    public List<SBQQ__QuoteLine__c> lstQuoteLine {get;set;}
    public List<SBQQ__Quote__c> lstQuote {get;set;}
    public List<Order> lstOrder {get;set;}
    public List<SBQQ__Quote__c> lstPurchaseDetails {get;set;}
    public Boolean showLines {get;set;}
    public Boolean showPurchaseDetails {get;set;}
    public Boolean showPricePerHour {get;set;}
    
    
    public BluEdgeOrderSummaryFormController(ApexPages.StandardController controller){
        Id recordId = ApexPages.currentPage().getParameters().get('id');
        String sobjectType = recordId.getSObjectType().getDescribe().getName();
        System.debug('Record Id: ' + recordId);
        if(sobjectType == 'SBQQ__Quote__c'){
            List<Order> lstOrder = [SELECT Id, SBQQ__Quote__c, SBQQ__Quote__r.NATT_Per_Hour_Billing__c, NATT_End_Customer__r.Name, SBQQ__Quote__r.NATT_Total_Unit_Quantity__c, SBQQ__Quote__r.NATT_End_Customer_Subtotal__c, SBQQ__Quote__r.NATT_Dealer_Copy__c, NATT_Quote_Name__c, SBQQ__Quote__r.NATT_Created_Date__c, SBQQ__Quote__r.SBQQ__ExpirationDate__c,
                           SBQQ__Quote__r.NATT_BluEdge_Price_Per_Hour_End_Customer__c, SBQQ__Quote__r.NATT_BluEdge_Price_Per_Hour__c, SBQQ__Quote__r.NATT_Quote_Record_Type_Developer_Name__c, SBQQ__Quote__r.NATT_Total_BluEdge_Customer_Amount__c, SBQQ__Quote__r.NATT_Total_EMCC_Amount__c, SBQQ__Quote__r.SBQQ__NetAmount__c,
                           NATT_Account_Name__c, SBQQ__Quote__r.SBQQ__SalesRep__r.Name, SBQQ__Quote__r.NATT_Dealer_Name__c, SBQQ__Quote__r.SBQQ__BillingStreet__c, SBQQ__Quote__r.SBQQ__BillingCity__c, 
                           SBQQ__Quote__r.SBQQ__BillingState__c, SBQQ__Quote__r.SBQQ__BillingPostalCode__c, SBQQ__Quote__r.SBQQ__BillingCountry__c, SBQQ__Quote__r.NATT_Dealer_Sales_Rep_Phone__c, NATT_Unit__c,
                           SBQQ__Quote__r.NATT_BluEdge_Core__c, SBQQ__Quote__r.NATT_BluEdge_Enhance__c, SBQQ__Quote__r.NATT_BluEdge_Elite__c, SBQQ__Quote__r.NATT_BluEdge_Document_Logo__c
                           FROM Order 
                           WHERE SBQQ__Quote__c =: recordId LIMIT 1];
               
            if(lstOrder.size() > 0){
                Order order = lstOrder[0];
                setOrderQLDetails(order, recordId);
                System.debug('Scenario 1');
            }
            else{
                SBQQ__Quote__c quote = [SELECT Id, NATT_Total_Unit_Quantity__c, NATT_Per_Hour_Billing__c, NATT_End_Customer__r.Name, NATT_BluEdge_Price_Per_Hour_End_Customer__c, NATT_BluEdge_Price_Per_Hour__c, NATT_Quote_Record_Type_Developer_Name__c, NATT_Total_BluEdge_Customer_Amount__c, NATT_Total_EMCC_Amount__c, SBQQ__NetAmount__c, NATT_End_Customer_Subtotal__c, NATT_Dealer_Copy__c, Name, NATT_Created_Date__c, SBQQ__ExpirationDate__c, NATT_Purchase_Order__c, SBQQ__Status__c, NATT_Converted_Date__c, NATT_Original_Order__c, CreatedDate,
                                   NATT_Account_Name__c, SBQQ__SalesRep__r.Name, NATT_Dealer_Name__c, SBQQ__BillingStreet__c, SBQQ__BillingCity__c, 
                                   SBQQ__BillingState__c, SBQQ__BillingPostalCode__c, SBQQ__BillingCountry__c, NATT_Dealer_Sales_Rep_Phone__c, NATT_Unit__c,
                                   NATT_BluEdge_Core__c, NATT_BluEdge_Enhance__c, NATT_BluEdge_Elite__c, NATT_BluEdge_Document_Logo__c
                                   FROM SBQQ__Quote__c WHERE Id =: recordId LIMIT 1];
                setQuoteQLDetails(quote, recordId);
                System.debug('Scenario 2');
            }
        }
        else{
            List<Order> lstOrder = [SELECT Id, SBQQ__Quote__c, SBQQ__Quote__r.NATT_Per_Hour_Billing__c, NATT_End_Customer__r.Name, SBQQ__Quote__r.NATT_Total_Unit_Quantity__c, SBQQ__Quote__r.NATT_End_Customer_Subtotal__c, SBQQ__Quote__r.NATT_Dealer_Copy__c, NATT_Quote_Name__c, SBQQ__Quote__r.NATT_Created_Date__c, SBQQ__Quote__r.SBQQ__ExpirationDate__c,
                           SBQQ__Quote__r.NATT_BluEdge_Price_Per_Hour_End_Customer__c, SBQQ__Quote__r.NATT_BluEdge_Price_Per_Hour__c, SBQQ__Quote__r.NATT_Quote_Record_Type_Developer_Name__c, SBQQ__Quote__r.NATT_Total_BluEdge_Customer_Amount__c, SBQQ__Quote__r.NATT_Total_EMCC_Amount__c, SBQQ__Quote__r.SBQQ__NetAmount__c,
                           NATT_Account_Name__c, SBQQ__Quote__r.SBQQ__SalesRep__r.Name, SBQQ__Quote__r.NATT_Dealer_Name__c, SBQQ__Quote__r.SBQQ__BillingStreet__c, SBQQ__Quote__r.SBQQ__BillingCity__c, 
                           SBQQ__Quote__r.SBQQ__BillingState__c, SBQQ__Quote__r.SBQQ__BillingPostalCode__c, SBQQ__Quote__r.SBQQ__BillingCountry__c, SBQQ__Quote__r.NATT_Dealer_Sales_Rep_Phone__c, NATT_Unit__c,
                           SBQQ__Quote__r.NATT_BluEdge_Core__c, SBQQ__Quote__r.NATT_BluEdge_Enhance__c, SBQQ__Quote__r.NATT_BluEdge_Elite__c, SBQQ__Quote__r.NATT_BluEdge_Document_Logo__c
                           FROM Order  
                           WHERE Id =: recordId LIMIT 1];
            if(lstOrder.size() > 0){
                Order order = lstOrder[0];
                setOrderQLDetails(order, recordId);
                System.debug('Scenario 3');
            }
        }
    }
    
    public void setOrderQLDetails(Order order, Id recordId){
        Decimal totalBluEdge = 0;
        for(SBQQ__QuoteLine__c qlQ : [SELECT Id, NATT_P_N__c, NATT_Grouped_By_Line_Number__c, SBQQ__Quantity__c FROM SBQQ__QuoteLine__c WHERE NATT_P_N__c Like 'BLUEDGE-%' AND SBQQ__Quote__c =: order.SBQQ__Quote__c]){
            if(qlQ.NATT_Grouped_By_Line_Number__c == 1 && totalBluEdge == 0){
                totalBluEdge += qlQ.SBQQ__Quantity__c;
            }
            if(qlQ.NATT_Grouped_By_Line_Number__c != 1){
                totalBluEdge += qlQ.SBQQ__Quantity__c;
            }
        }
        lstPurchaseDetails = new List<SBQQ__Quote__c>();
            if(order.SBQQ__Quote__r.NATT_BluEdge_Core__c){
                typeBluEdge = 'Core';
            }
            if(order.SBQQ__Quote__r.NATT_BluEdge_Enhance__c){
                typeBluEdge = 'Enhance';
            }
            if(order.SBQQ__Quote__r.NATT_BluEdge_Elite__c){
                typeBluEdge = 'Elite';
            }
            if(order.SBQQ__Quote__r.NATT_Dealer_Copy__c){
                dealerCopy = true;
            }
                
            logoBluEdge = order.SBQQ__Quote__r.NATT_BluEdge_Document_Logo__c;
            quoteID = order.NATT_Quote_Name__c;
            quoteDate = order.SBQQ__Quote__r.NATT_Created_Date__c.month() + '/' + order.SBQQ__Quote__r.NATT_Created_Date__c.day() + '/' + order.SBQQ__Quote__r.NATT_Created_Date__c.year();
            quoteExpires = order.SBQQ__Quote__r.SBQQ__ExpirationDate__c.month() + '/' + order.SBQQ__Quote__r.SBQQ__ExpirationDate__c.day() + '/' + order.SBQQ__Quote__r.SBQQ__ExpirationDate__c.year();
            customerName = order.NATT_End_Customer__r.Name != null ? order.NATT_End_Customer__r.Name : order.NATT_Account_Name__c;
            salesRepName = order.SBQQ__Quote__r.SBQQ__SalesRep__r.Name;
            dealerName = order.SBQQ__Quote__r.NATT_Dealer_Name__c;
            billingStreet = order.SBQQ__Quote__r.SBQQ__BillingStreet__c;
            billingCity = order.SBQQ__Quote__r.SBQQ__BillingCity__c;
            billingState = order.SBQQ__Quote__r.SBQQ__BillingState__c;
            billingPostalCode = order.SBQQ__Quote__r.SBQQ__BillingPostalCode__c;
            billingCountry = order.SBQQ__Quote__r.SBQQ__BillingCountry__c;
            dealerPhone = order.SBQQ__Quote__r.NATT_Dealer_Sales_Rep_Phone__c;
            unitModel = order.NATT_Unit__c;
            pricePerHour = order.SBQQ__Quote__r.NATT_BluEdge_Price_Per_Hour_End_Customer__c;
            showPricePerHour = order.SBQQ__Quote__r.NATT_Per_Hour_Billing__c;

            if(order.SBQQ__Quote__r.NATT_Quote_Record_Type_Developer_Name__c != 'NATT_BluEdge' && order.SBQQ__Quote__r.NATT_Quote_Record_Type_Developer_Name__c != 'CTBR_BluEdge'){
                pricePerUnit = order.SBQQ__Quote__r.NATT_Total_BluEdge_Customer_Amount__c / order.SBQQ__Quote__r.NATT_Total_Unit_Quantity__c;
                System.debug('CTBR pricePerUnit :'+pricePerUnit);
                if(order.SBQQ__Quote__r.NATT_Dealer_Copy__c){
                    pricePerUnit = order.SBQQ__Quote__r.NATT_Total_Unit_Quantity__c > 0 ? order.SBQQ__Quote__r.NATT_Total_EMCC_Amount__c / order.SBQQ__Quote__r.NATT_Total_Unit_Quantity__c: order.SBQQ__Quote__r.NATT_Total_EMCC_Amount__c / totalBluEdge;
                   System.debug('Dealer pricePerUnit :'+pricePerUnit);
                    pricePerHour = order.SBQQ__Quote__r.NATT_BluEdge_Price_Per_Hour__c;
                }
            }
            else {
                pricePerUnit = order.SBQQ__Quote__r.NATT_Total_Unit_Quantity__c > 0 ? order.SBQQ__Quote__r.NATT_End_Customer_Subtotal__c / order.SBQQ__Quote__r.NATT_Total_Unit_Quantity__c : order.SBQQ__Quote__r.NATT_End_Customer_Subtotal__c / totalBluEdge;
                System.debug('End pricePerUnit :'+pricePerUnit);
                if(order.SBQQ__Quote__r.NATT_Dealer_Copy__c){
                    pricePerUnit = order.SBQQ__Quote__r.NATT_Total_Unit_Quantity__c > 0 ? order.SBQQ__Quote__r.SBQQ__NetAmount__c / order.SBQQ__Quote__r.NATT_Total_Unit_Quantity__c : order.SBQQ__Quote__r.SBQQ__NetAmount__c / totalBluEdge;
                   System.debug('pricePerUnit Dealer 3 :'+pricePerUnit);
                    pricePerHour = order.SBQQ__Quote__r.NATT_BluEdge_Price_Per_Hour__c;
                }
            }
                
            lstQuoteLine = new List<SBQQ__QuoteLine__c> ([SELECT Id, SBQQ__Number__c, SBQQ__ProductName__c, NATT_Months__c, NATT_Hours__c, NATT_BluEdge_Price_Type__c,
                            NATT_Major_Component_Deductible__c, NATT_Major_Component_Months__c, NATT_Major_Component_Hours__c, NATT_Deductibles2__c, NATT_Deductibles__c,
                            CTBR_Months__c, CTBR_Hours__c, CTBR_Deductibles__c, CTBR_Major_Component_Deductible__c, CTBR_Major_Component_Months__c, CTBR_Major_Component_Hours__c
                            FROM SBQQ__QuoteLine__c
                            WHERE SBQQ__Quote__c =: order.SBQQ__Quote__c AND SBQQ__Hidden__c = false AND SBQQ__ProductOption__r.SBQQ__QuoteLineVisibility__c != 'Never' AND
                            SBQQ__ProductOption__r.SBQQ__QuoteLineVisibility__c != 'Editor Only'  AND NATT_EMCC__c = TRUE AND NATT_Grouped_By_Line_Number__c = 1
                            ORDER BY SBQQ__Number__c]);
            
            if(lstQuoteLine.size() > 0){
                showLines = true;
            }
            
            lstOrder = new List<Order> ([SELECT Id, NATT_Purchase_Order__c, ActivatedDate, SBQQ__Quote__c, NATT_Original_Order_Id__c, CreatedDate
                                                  FROM Order
                                                  WHERE (NATT_Original_Order_Id__c=: order.Id OR Id =: order.Id)
                                                  ORDER BY CreatedDate]);
                                           
            Set<Id> quoteIds= new Set<Id>();
            Set<Id> setQuote= new Set<Id>();
            Map<Id,Order> mapOrder = new Map<Id,Order>();
            
            for(Order ord : lstOrder){
                mapOrder.put(ord.SBQQ__Quote__c, ord);
                quoteIds.add(ord.SBQQ__Quote__c);
            }
            System.debug('Quote Ids: ' + quoteIds);
            
            for(SBQQ__QuoteLine__c ql : [SELECT Id, NATT_Inventory__c, NATT_Inventory__r.NATT_Serial_Number__c, SBQQ__Quote__c FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c IN:quoteIds]){
                System.debug('Added to setQuote: ' + setQuote.contains(ql.SBQQ__Quote__c));
                System.debug('Inventory not null: ' + ql.NATT_Inventory__c != null);
                System.debug('Purchase not null: ' + mapOrder.get(ql.SBQQ__Quote__c).NATT_Purchase_Order__c != null);
                if(!setQuote.contains(ql.NATT_Inventory__c) && ql.NATT_Inventory__c != null && mapOrder.get(ql.SBQQ__Quote__c).NATT_Purchase_Order__c != null){
                    SBQQ__Quote__c newQuote = new SBQQ__Quote__c();
                    newQuote.NATT_Purchase_Order__c = mapOrder.get(ql.SBQQ__Quote__c).NATT_Purchase_Order__c;
                    newQuote.NATT_Converted_Date__c= mapOrder.get(ql.SBQQ__Quote__c).ActivatedDate;
                    newQuote.SBQQ__Notes__c = ql.NATT_Inventory__r.NATT_Serial_Number__c;

                    lstPurchaseDetails.add(newQuote);
                    setQuote.add(ql.NATT_Inventory__c);
                } 
            }
            System.debug('Purchase Details: ' + lstPurchaseDetails);
            if(lstPurchaseDetails.size() > 0){
                showPurchaseDetails = true;
            }
    }
    
    public void setQuoteQLDetails(SBQQ__Quote__c quote, Id recordId){
        Decimal totalBluEdge = 0;
        for(SBQQ__QuoteLine__c qlQ : [SELECT Id, NATT_P_N__c, NATT_Grouped_By_Line_Number__c, SBQQ__Quantity__c FROM SBQQ__QuoteLine__c WHERE NATT_P_N__c Like 'BLUEDGE-%' AND SBQQ__Quote__c =: quote.Id]){
            if(qlQ.NATT_Grouped_By_Line_Number__c == 1 && totalBluEdge == 0){
                totalBluEdge += qlQ.SBQQ__Quantity__c;
            }
            if(qlQ.NATT_Grouped_By_Line_Number__c != 1){
                totalBluEdge += qlQ.SBQQ__Quantity__c;
            }
        }
        lstPurchaseDetails = new List<SBQQ__Quote__c>();
            if(quote.NATT_BluEdge_Core__c){
                    typeBluEdge = 'Core';
            }
            if(quote.NATT_BluEdge_Enhance__c){
                typeBluEdge = 'Enhance';
            }
            if(quote.NATT_BluEdge_Elite__c){
                typeBluEdge = 'Elite';
            }
            if(quote.NATT_Dealer_Copy__c){
                dealerCopy = true;
            }
            List<SBQQ__QuoteLine__c> quotesWithLines=[Select Id,SBQQ__Product__r.Name,NATT_CMRA_Term_Hours__c,NATT_End_Customer_Price__c from SBQQ__QuoteLine__c where SBQQ__Quote__c =: quote.Id]; 
            for(SBQQ__QuoteLine__c Qlines:quotesWithLines){
            string productLabelvalue=Label.BluEdge_Price_Caluculation;
            string productName=Qlines.SBQQ__Product__r.Name;
                if(productLabelvalue.contains(productName)){
                   quote.NATT_BluEdge_Price_Per_Hour_End_Customer__c=Qlines.NATT_End_Customer_Price__c/Qlines.NATT_CMRA_Term_Hours__c; 
                    System.debug('Testresults:'+quote.NATT_BluEdge_Price_Per_Hour_End_Customer__c);
                }
             }
            logoBluEdge = quote.NATT_BluEdge_Document_Logo__c;
            quoteID = quote.Name;
            System.debug('quoteID Test:'+quoteID );
            quoteDate = quote.NATT_Created_Date__c.month() + '/' + quote.NATT_Created_Date__c.day() + '/' + quote.NATT_Created_Date__c.year();
            quoteExpires = quote.SBQQ__ExpirationDate__c.month() + '/' + quote.SBQQ__ExpirationDate__c.day() + '/' + quote.SBQQ__ExpirationDate__c.year();
            customerName = quote.NATT_End_Customer__r.Name != null ? quote.NATT_End_Customer__r.Name : quote.NATT_Account_Name__c;
            salesRepName = quote.SBQQ__SalesRep__r.Name;
            dealerName = quote.NATT_Dealer_Name__c;
            billingStreet = quote.SBQQ__BillingStreet__c;
            billingCity = quote.SBQQ__BillingCity__c;
            billingState = quote.SBQQ__BillingState__c;
            billingPostalCode = quote.SBQQ__BillingPostalCode__c;
            billingCountry = quote.SBQQ__BillingCountry__c;
            dealerPhone = quote.NATT_Dealer_Sales_Rep_Phone__c;
            unitModel = quote.NATT_Unit__c;
            //quote.NATT_BluEdge_Price_Per_Hour_End_Customer__c=quote.NATT_End_Customer_Price__c/quote.NATT_CMRA_Term_Hours__c;
            pricePerHour = quote.NATT_BluEdge_Price_Per_Hour_End_Customer__c;
            System.debug('User Test:'+pricePerHour);
            showPricePerHour = quote.NATT_Per_Hour_Billing__c;
            
            if(quote.NATT_Quote_Record_Type_Developer_Name__c != 'NATT_BluEdge' && quote.NATT_Quote_Record_Type_Developer_Name__c != 'CTBR_BluEdge'){
                pricePerUnit = quote.NATT_Total_Unit_Quantity__c > 0 ? quote.NATT_Total_BluEdge_Customer_Amount__c / quote.NATT_Total_Unit_Quantity__c :  quote.NATT_Total_BluEdge_Customer_Amount__c / totalBluEdge;
                System.debug('Dealer pricePerUnit 5 :'+pricePerUnit);
                if(quote.NATT_Dealer_Copy__c){
                    pricePerUnit = quote.NATT_Total_Unit_Quantity__c > 0 ? quote.NATT_Total_EMCC_Amount__c / quote.NATT_Total_Unit_Quantity__c : quote.NATT_Total_EMCC_Amount__c / totalBluEdge;
                    System.debug('Dealer pricePerUnit 6 :'+pricePerUnit);
                    pricePerHour = quote.NATT_BluEdge_Price_Per_Hour__c;
                }
            }
            else {
                pricePerUnit = quote.NATT_Total_Unit_Quantity__c > 0 ? quote.NATT_End_Customer_Subtotal__c / quote.NATT_Total_Unit_Quantity__c : quote.NATT_End_Customer_Subtotal__c / totalBluEdge;
                System.debug('Dealer pricePerUnit 7 :'+pricePerUnit);
                if(quote.NATT_Dealer_Copy__c){
                    pricePerUnit = quote.NATT_Total_Unit_Quantity__c > 0 ? quote.SBQQ__NetAmount__c / quote.NATT_Total_Unit_Quantity__c : quote.SBQQ__NetAmount__c / totalBluEdge;
                    System.debug('Dealer pricePerUnit 8:'+pricePerUnit);
                    pricePerHour = quote.NATT_BluEdge_Price_Per_Hour__c;
                }
            }
            
            lstQuoteLine = new List<SBQQ__QuoteLine__c> ([SELECT Id, SBQQ__Number__c, SBQQ__ProductName__c, NATT_Months__c, NATT_Hours__c, NATT_BluEdge_Price_Type__c,
                            NATT_Major_Component_Deductible__c, NATT_Major_Component_Months__c, NATT_Major_Component_Hours__c, NATT_Deductibles2__c, NATT_Deductibles__c,
                            CTBR_Months__c, CTBR_Hours__c, CTBR_Deductibles__c, CTBR_Major_Component_Deductible__c, CTBR_Major_Component_Months__c, CTBR_Major_Component_Hours__c
                            FROM SBQQ__QuoteLine__c
                            WHERE SBQQ__Quote__c =: quote.Id AND SBQQ__Hidden__c = false AND SBQQ__ProductOption__r.SBQQ__QuoteLineVisibility__c != 'Never' AND
                            SBQQ__ProductOption__r.SBQQ__QuoteLineVisibility__c != 'Editor Only'  AND NATT_EMCC__c = TRUE AND NATT_Grouped_By_Line_Number__c = 1
                            ORDER BY SBQQ__Number__c]);
            
            if(lstQuoteLine.size() > 0){
                showLines = true;
            }
            
            Set<Id> setQuote= new Set<Id>();
            
            for(SBQQ__QuoteLine__c ql : [SELECT Id, NATT_Inventory__c, NATT_Inventory__r.NATT_Serial_Number__c, SBQQ__Quote__c FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c =: recordId]){
                if(!setQuote.contains(ql.NATT_Inventory__c) && ql.NATT_Inventory__c != null && quote.NATT_Purchase_Order__c != null){
                    SBQQ__Quote__c newQuote = new SBQQ__Quote__c();
                    newQuote.NATT_Purchase_Order__c = quote.NATT_Purchase_Order__c;
                    newQuote.NATT_Converted_Date__c= quote.CreatedDate;
                    newQuote.SBQQ__Notes__c = ql.NATT_Inventory__r.NATT_Serial_Number__c;

                    lstPurchaseDetails.add(newQuote);
                    setQuote.add(ql.NATT_Inventory__c);
                } 
            }
            System.debug('Purchase Details: ' + lstPurchaseDetails);
            if(lstPurchaseDetails.size() > 0){
                showPurchaseDetails = true;
            }
    }
}