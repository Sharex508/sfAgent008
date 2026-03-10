public without sharing class NattOrderSearchController {
    
    @AuraEnabled
    public static boolean isCommunity_Apex(){
        Id siteId = Site.getSiteId(); // take a look at the apex class Site, you may find more useful method concerning site/community
        if (siteId != null) {
            return true;
        }
        return false;
    }
    
    
    @AuraEnabled
    public static boolean isJDESalesOrder_NotNull(String selectedOrderId){
        Order odr = [Select Id, AccountId, NATT_Original_Order_Id__c, NATT_JDE_SALES_ORDER_NUMBER__C,NATT_Recordtype_Developer_Name__c From Order Where Id = :selectedOrderId];       
        if(odr.NATT_JDE_SALES_ORDER_NUMBER__C <> null && odr.NATT_Recordtype_Developer_Name__c.startsWithIgnoreCase('Natt_Units')){
            return true;
        }
        return false;
    }
    
    @AuraEnabled
    public static String getOpenAmendmentOrderNumber_Apex(String selectedOrderId){    
        Order odr = [Select Id,AccountId,NATT_Original_Order_Id__c From Order Where Id = :selectedOrderId];        
        Order newOrder = [Select Id, OrderNumber From Order Where Type = 'Amendment' AND NATT_Original_Order_Id__c = :odr.NATT_Original_Order_Id__c ORDER BY CreatedDate DESC Limit 1];

        return newOrder.OrderNumber;
    }
    
    @AuraEnabled
    public static Boolean hasOpenAmendment2_Apex(String selectedOrderId){        
        Boolean openAmendmentQuoteFound = false;        
        
        Order odr = [Select Id,AccountId,NATT_Original_Order_Id__c, CreatedDate From Order Where Id = :selectedOrderId];        
        
        if(odr.NATT_Original_Order_Id__c <> null){            
            // get open amendment quote
            Integer openAmendmentQuoteCount = [Select Count() From Order Where Type = 'Amendment' AND NATT_Original_Order_Id__c = :odr.NATT_Original_Order_Id__c AND Id != :selectedOrderId AND CreatedDate > :odr.CreatedDate ];
            
            if(openAmendmentQuoteCount > 0){
                openAmendmentQuoteFound = true;
            }
        }        
        return openAmendmentQuoteFound;
    }
    
    @AuraEnabled
    public static Boolean hasOpenAmendment_Apex(String selectedOrderId){        
        Boolean openAmendmentQuoteFound = false;        
        
        Order odr = [Select Id,AccountId,NATT_Original_Order_Id__c From Order Where Id = :selectedOrderId];        
        
        if(odr.NATT_Original_Order_Id__c <> null){            
            // get open amendment quote
            Integer openAmendmentQuoteCount = [Select Count() From SBQQ__Quote__c 
                                               Where SBQQ__Primary__c = true 
                                               AND NATT_Original_Order_Id__c = :odr.NATT_Original_Order_Id__c
                                               AND SBQQ__Opportunity2__r.StageName != 'Closed Lost' 
                                               AND SBQQ__Ordered__c = false
                                               AND SBQQ__Type__c = 'Amendment'];
            
            if(openAmendmentQuoteCount > 0){
                openAmendmentQuoteFound = true;
            }
        }        
        return openAmendmentQuoteFound;
    }
    
    @AuraEnabled
    public static Boolean getShipmentMethodEditable_Apex(String selectedOrderId){
        Boolean shipmentMethodEditable = true;        
        for(OrderItem oi : [Select Id,
                            NATT_Locked__c
                            From OrderItem 
                            Where OrderId = :selectedOrderId
                            AND NATT_Is_Base_Unit__c = true])
        {
            if(oi.NATT_Locked__c){
                shipmentMethodEditable = false;
                break;
            }            
        }       
        return shipmentMethodEditable;
    }
    
    @AuraEnabled
    public static List<OrderItemWrapper> fetchRelatedUnits_Apex(String selectedOrderId){        
        Set<Id> setOI = new Set<Id>(); 
        Order odr = [Select Id,AccountId,NATT_Original_Order_Id__c From Order Where Id = :selectedOrderId]; 
        List<OrderItem> lstOrderItems = [Select Id,
                            Quantity,
                            NATT_QuoteLine_Id_for_Amendment__c,
                            NATT_Locked__c,
                            NATT_Product_Name__c,
                            NATT_P_N__c,
                            NATT_Requested_Ship_Date__c,
                            NATT_Unit_Name__c,
                            NATT_Is_Base_Unit__c,
                            NATT_Grouped_By_Line_Number__c,
                            Order.Owner.Name,
                            Order.NATT_JDE_Sales_Order_Number__c,
                            Order.Type,
                            Order.CreatedDate,
                            OrderId,
                            NATT_Original_Order_Id__c
                            From OrderItem 
                            Where NATT_Original_Order_Id__c = :odr.NATT_Original_Order_Id__c
                            //AND NATT_Current_Effective_Quantity__c > 0
                            AND NATT_Locked__c = false
                            AND NATT_Is_Base_Unit__c = true
                            ORDER BY NATT_QuoteLine_Id_for_Amendment__c];
                            
        List<OrderItemWrapper> oderLinesWrapper = new List<OrderItemWrapper>();
        Map<Id,Decimal> quotelineIdtoQuantityMap = new Map<Id,Decimal>();
        Decimal totalQty = 0;
        for(OrderItem oi : lstOrderItems)
        {
            if(quotelineIdtoQuantityMap.containsKey(oi.NATT_QuoteLine_Id_for_Amendment__c)){
                totalQty = quotelineIdtoQuantityMap.get(oi.NATT_QuoteLine_Id_for_Amendment__c) + oi.Quantity;
                quotelineIdtoQuantityMap.put(oi.NATT_QuoteLine_Id_for_Amendment__c, totalQty);
            } else{
                quotelineIdtoQuantityMap.put(oi.NATT_QuoteLine_Id_for_Amendment__c, oi.Quantity);
            }
        }
        
        for(OrderItem oi : lstOrderItems)
        {
            if(quotelineIdtoQuantityMap.get(oi.NATT_QuoteLine_Id_for_Amendment__c) > 0){
                if(oi.NATT_Original_Order_Id__c.equals(odr.NATT_Original_Order_Id__c)){
                setOI.add(oi.Id);
                oderLinesWrapper.add(new OrderItemWrapper(oi,false,false));
                }
            } 
        }
        //SHOW ASSETS
        List<Asset> showAssets = new List<Asset>();   
        for(Asset ha : [Select Id,
                        NATT_Hide_Asset__c,
                        CustomUsageEndDate__c,
                        UsageEndDate,
                        NATT_Hidden_By__c,
                        NATT_Original_Order_Id__c
                        From Asset 
                        Where ((SBQQ__OrderProduct__c =: setOI AND NATT_Is_Base_Unit__c = true) OR (NATT_Is_Base_Unit__c = false AND NATT_Original_Order_Id__c =:odr.NATT_Original_Order_Id__c))
                        AND AccountId =:odr.AccountId])
        {
            ha.NATT_Hide_Asset__c = false;
            ha.NATT_Hidden_By__c = null;
            if(ha.CustomUsageEndDate__c){
                ha.CustomUsageEndDate__c = false;
                ha.UsageEndDate = null;
            }
            showAssets.add(ha);                
        }
        if(!showAssets.isEmpty()){
        update showAssets;
        }        
        return oderLinesWrapper;
    }
    
    @AuraEnabled
    public static void hideOtherAssets_Apex(String selectedOrderId){        
        Order odr = [Select Id,AccountId,NATT_Original_Order_Id__c From Order Where Id = :selectedOrderId];        
        List<Asset> hideAssets = new List<Asset>();      
        //HIDE ASSETS
        for(Asset ha : [Select Id,
                        NATT_Hide_Asset__c,
                        UsageEndDate,
                        CustomUsageEndDate__c,
                        NATT_Original_Order_Id__c
                        From Asset 
                        Where 
                        (NATT_Original_Order_Id__c != :odr.NATT_Original_Order_Id__c
                         AND AccountId = :odr.AccountId) AND UsageEndDate = null])
        {
            ha.NATT_Hide_Asset__c = true;
            ha.NATT_Hidden_By__c = UserInfo.getUserId();
            ha.UsageEndDate = System.Today() - 365;
            ha.CustomUsageEndDate__c = true;
            hideAssets.add(ha);                
        }
        
        if(!hideAssets.isEmpty()){        
        update hideAssets;
        }

        //call auto launched flow
        //Flow.Interview flow = new Flow.Interview.Reset_Hide_Assets(new map<String,Object>{'varSalesOrderId' => odr.NATT_Original_Order_Id__c,'varAccountId' => odr.AccountId});     
        //flow.start();
    }
    
    @AuraEnabled
    public static boolean validateRequestedDatePriceChanges_Apex(String newRequestedShipDate,String orderItemId){        
        
        Boolean isValidChange = true;
        Map<String,OrderItem> odrproductPriceMap = new Map<String,OrderItem>();         
        OrderItem oi = [Select Id,NATT_Grouped_By_Line_Number__c,OrderId From OrderItem where Id = :orderItemId];
        
        for(OrderItem oli : [Select Id,
                             ListPrice,
                             Product2.ProductCode,
                             SBQQ__QuoteLine__r.SBQQ__ProductCode__c,
                             NATT_Requested_Ship_Date__c,
                             NATT_Grouped_By_Line_Number__c,
                             SBQQ__QuotedListPrice__c,
                             NATT_Lotus_Notes_Price__c
                             From OrderItem 
                             Where OrderId =:oi.OrderId
                             AND NATT_Grouped_By_Line_Number__c = :oi.NATT_Grouped_By_Line_Number__c])
        {
            odrproductPriceMap.put(oli.Product2.ProductCode,oli);              
        }
        
        try{
            for(SBQQ__LookupData__c ld : [Select Id,NATT_Product_Code__c,
                                          NATT_Price__c,NATT_Start_Date__c,NATT_End_Date__c
                                          From SBQQ__LookupData__c 
                                          Where SBQQ__Type__c = 'Unit Pricing'
                                          AND NATT_Product_Code__c IN :odrproductPriceMap.keySet()
                                          //AND NATT_Start_Date__c <= TODAY 
                                          //AND NATT_End_Date__c >= TODAY
                                          ])
            {
                if(odrproductPriceMap.get(ld.NATT_Product_Code__c).NATT_Requested_Ship_Date__c >= ld.NATT_Start_Date__c &&
                   odrproductPriceMap.get(ld.NATT_Product_Code__c).NATT_Requested_Ship_Date__c <= ld.NATT_End_Date__c){
                   if(Date.valueOf(newRequestedShipDate) < ld.NATT_Start_Date__c || Date.valueOf(newRequestedShipDate) > ld.NATT_End_Date__c){
                        isValidChange=false;
                   }
                }
            }  
        }catch(Exception e){
            //throw all other exception message
            throw new AuraHandledException(e.getMessage());
        }
        return isValidChange;
    }
    
    @AuraEnabled
    public static void saveRequestedShipDateChanges_Apex(String selectedOrderId,String newReqShipDate,String orderItemId){        
        Set<Date> reqShipDateSet = new Set<Date>();
        Map<String,OrderItem> odrproductPriceMap = new Map<String,OrderItem>(); 
        //  Map<Decimal,OrderItemWrapper> orderItemWrapperMap = new Map<Decimal,OrderItemWrapper>();        
        //  List<OrderItemWrapper> orderLines = (List<OrderItemWrapper>)JSON.deserialize(orderLinesJSON,List<OrderItemWrapper>.class);
        OrderItem oi = [Select Id,NATT_Grouped_By_Line_Number__c,OrderId From OrderItem where Id = :orderItemId];        
        System.debug('orderItemId GroupedByLineNumber'+oi.NATT_Grouped_By_Line_Number__c);        
        for(OrderItem oli : [Select Id,
                             ListPrice,
                             Product2.ProductCode,
                             SBQQ__QuoteLine__r.SBQQ__ProductCode__c,
                             NATT_Requested_Ship_Date__c,
                             NATT_Grouped_By_Line_Number__c,
                             SBQQ__QuotedListPrice__c 
                             From OrderItem 
                             Where OrderId =:selectedOrderId
                             AND NATT_Grouped_By_Line_Number__c = :oi.NATT_Grouped_By_Line_Number__c])
        {
            odrproductPriceMap.put(oli.Product2.ProductCode,oli);
            
            // update the requested ship date
            odrproductPriceMap.get(oli.Product2.ProductCode).NATT_Requested_Ship_Date__c = Date.valueOf(newReqShipDate);
        }
        if(odrproductPriceMap.isEmpty()){
            //just update the record in question
            odrproductPriceMap.put(orderItemId,new OrderItem(Id=orderItemId,NATT_Requested_Ship_Date__c=Date.valueOf(newReqShipDate)));
        }
        
        // update new requested ship date
        update odrproductPriceMap.values();
    }
    
    @AuraEnabled
    public static void saveOrder_Apex(String selectedOrderId,
                                      String purchaseOrder,
                                      String marketSegment,
                                      String markSpecialInstructions,
                                      String endCustomerId,
                                      Boolean dealerStock,
                                      String dealerComments,
                                      String shipmentMethod,
                                      String shippingAddress)
    {
        Order o = new Order(Id = selectedOrderId,
                            NATT_Purchase_Order__c = purchaseOrder,
                            NATT_Market_Segment2__c = marketSegment,
                            NATT_Mark_For_Special_Delivery_Instructi__c = markSpecialInstructions,
                            NATT_End_Customer__c = endCustomerId,
                            NATT_Stock__c= dealerStock,
                            NATT_Dealer_Comments__c = dealerComments,
                            NATT_Shipment_Method__c = shipmentMethod,
                            NATT_Shipping_Address__c = shippingAddress);
        if(String.isNotBlank(shippingAddress)){
            NATT_Address__c address = [SELECT Id,NATT_Street__c,NATT_City__c,NATT_State_Province__c,NATT_Zip_Postal_Code__c,NATT_Country__c FROM NATT_Address__c WHERE Id=:shippingAddress];
            o.ShippingStreet = address.NATT_Street__c;
            o.ShippingCity = address.NATT_City__c;
            o.ShippingState = address.NATT_State_Province__c;
            o.ShippingPostalCode= address.NATT_Zip_Postal_Code__c;
            o.ShippingCountry = address.NATT_Country__c;
        }
        update o;
    }   
    
    public class OrderItemWrapper{        
        @AuraEnabled
        public String orderItemId;        
        @AuraEnabled
        public String orderId;        
        @AuraEnabled
        public String ownerName;        
        @AuraEnabled
        public String orderNumber;        
        @AuraEnabled
        public String orderType;        
        @AuraEnabled
        public String productName;        
        @AuraEnabled
        public Decimal groupByLineNumber;        
        @AuraEnabled
        public Date requestedShipDate;        
        @AuraEnabled
        public Date orderCreatedDate;        
        @AuraEnabled
        public Boolean rowLocked;        
        @AuraEnabled
        public Boolean reqShipDateChanged;        
        @AuraEnabled
        public Boolean reqShipDateChangedUpdated;
        @AuraEnabled
        public Boolean disableReqShipDate {get;set;}
        
        public OrderItemWrapper(OrderItem odritem,Boolean reqShipDateChanged,Boolean reqShipDateChangedUpdated){            
            this.rowLocked = odritem.NATT_Locked__c ? true : false;            
            this.orderItemId = odritem.Id;            
            this.orderId = odritem.OrderId;            
            this.productName = odritem.NATT_Product_Name__c;            
            this.requestedShipDate = odritem.NATT_Requested_Ship_Date__c;            
            this.ownerName = odritem.Order.Owner.Name;            
            this.orderCreatedDate = Date.valueOf(odritem.Order.CreatedDate);            
            this.orderNumber = odritem.Order.NATT_JDE_Sales_Order_Number__c;            
            this.orderType = odritem.Order.Type;            
            this.groupByLineNumber = odritem.NATT_Grouped_By_Line_Number__c;            
            this.reqShipDateChanged = reqShipDateChanged;            
            this.reqShipDateChangedUpdated = reqShipDateChangedUpdated;
            this.disableReqShipDate=false;
        }
    }   
}