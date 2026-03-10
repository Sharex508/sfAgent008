/** screens
 * Grabs Order Items for Order, Invoice/Shipments, Print View screens 
 */
public with sharing class NATT_TesOrderDetailsCon {
    /**
     * Wrapper classs that are used to store Order and Invoice page data.
     */
    public Class OrderWrapper {
        @AuraEnabled public List < OrderItemWrapper > orderItems{get;set;}
        @AuraEnabled public List < Shipment > shipments {get;set;}
        @AuraEnabled public Decimal partTotal {get;set;}
        @AuraEnabled public Decimal taxTotal {get;set;}
        @AuraEnabled public Decimal freightTotal {get;set;}
        @AuraEnabled public Decimal rushOrderTotal {get;set;}
        @AuraEnabled public Decimal orderTotal {get;set;}
        @AuraEnabled public Decimal partTotalValue {get;set;}
        @AuraEnabled public Decimal freightTotalValue {get;set;}
        @AuraEnabled public Decimal rushOrderTotalValue {get;set;}
        @AuraEnabled public Decimal orderTotalValue {get;set;}
        @AuraEnabled public Decimal shippedTotalValue {get;set;}
        @AuraEnabled public String Id {get;set;}
    }
    
    public Class OrderItemWrapper {
        @AuraEnabled public String Id {get;set;}
        @AuraEnabled public Decimal lineNum {get;set;}
        @AuraEnabled public String partNum {get;set;}
        @AuraEnabled public String description {get;set;}
        @AuraEnabled public Decimal  ordered {get;set;}
        @AuraEnabled public Decimal  delivered {get;set;}
        @AuraEnabled public Decimal  backOrdered {get;set;}
        @AuraEnabled public Decimal  amount {get;set;}
        @AuraEnabled public String status {get;set;}
        @AuraEnabled public Integer shipments {get;set;}
        @AuraEnabled public Decimal orderLineNum {get;set;}
        @AuraEnabled public Decimal unitPrice {get;set;}
        @AuraEnabled public Decimal orderItemPrice {get;set;}
        @AuraEnabled public Decimal orderItemAmount {get;set;}
        @AuraEnabled public Decimal shipmentItemAmount {get;set;}
        @AuraEnabled public String orderItemUOM {get;set;}
        @AuraEnabled public String trackingNumber {get;set;}
        @AuraEnabled public String expectedDelivery {get;set;}
        @AuraEnabled public String shipItemNum {get;set;}
        @AuraEnabled public Decimal rushFeeItem {get;set;}
        @AuraEnabled public String availablePromiseDate {get;set;}
    }
    /**
     * Method used to grab data for Order Lines section of Order Details page.
     * Grabs a list of Order Items and populates a OrderItemWrapper.
     * OrderItemWrapper is stored in OrderWrapper, which is cycled through on details page.
     */
    @AuraEnabled(cacheable = true)
    public static OrderWrapper fetchOrderlines(String recordId) {
        System.debug('Fetch Order Lines: ' + recordId);
        List < OrderItemWrapper > orderItemList = new List < OrderItemWrapper >();
        OrderWrapper wrapper = wrapperCreation('Order Total Values');
        
        //method used to grab orderitems (products) for invoice
        List <OrderItem> orderLines = grabOrderItems(recordId);
        
        for(OrderItem oi : orderlines){
            if(oi.TypeCode=='Charge' && oi.Type=='Delivery Charge'){ 
                //Freight Product 
                if(oi.Product2.Name.contains('FREIGHT')){
                    wrapper.freightTotalValue += oi.UnitPrice;
                    wrapper.orderTotalValue += oi.UnitPrice;
                    continue;
                }
                //Rush Fee Product
                if(oi.Product2.Name.contains('Rush Fee') || oi.NATT_OrderLineNumber__c == 990){
                    wrapper.rushOrderTotalValue += oi.UnitPrice;
                    wrapper.orderTotalValue += oi.UnitPrice;
                    continue;
                }
            }
            OrderItemWrapper oItemWrapper = assignOrderItemWrapperFields(oi, wrapper);
            Decimal amountHold = 0;
            orderItemList.add(oItemWrapper);

            //assignments for Totals            
            wrapper.partTotalValue += oItemWrapper.amount;
            wrapper.orderTotalValue += (oItemWrapper.amount);
        }

        //grab order total
        //Order orderInfo = [SELECT TotalAmount FROM Order WHERE Id = :recordId];
        //System.debug('TOTAL AMOUNT: ' + orderInfo.TotalAmount);

        //Query shipment objects for Shipment column in Order Lines
        List < Shipment > shpmnts = [SELECT Id, NATT_InvoiceNumber__c, NATT_PackingSlipNumber__c, NATT_DateShipped__c, NATT_ShippingCompanyName__c,
            TrackingNumber, NATT_BillOfLading__c FROM Shipment WHERE NATT_Order__c =: recordId];
            
        wrapper.shipments = shpmnts;
        wrapper.orderItems = orderItemList;
        wrapper.partTotal = (wrapper.partTotalValue);
        wrapper.freightTotal = (wrapper.freightTotalValue);
        wrapper.rushOrderTotal = (wrapper.rushOrderTotalValue);
        //wrapper.orderTotal = (orderInfo.TotalAmount);
        wrapper.orderTotal = wrapper.orderTotalValue;
       
        return wrapper;
    }

    /**
     * Creates OrderWrapper object for Order and Invoice details page.
     * OrderWrapper used to display the different totals.
     */
    private static OrderWrapper wrapperCreation(String wrapperName){
        OrderWrapper wrapper = new OrderWrapper();
        wrapper.Id = wrapperName;
        wrapper.partTotalValue = 0;
        wrapper.freightTotalValue = 0;
        wrapper.rushOrderTotalValue = 0;
        wrapper.orderTotalValue = 0;
        wrapper.shippedTotalValue=0;
        return wrapper;
    }

     /**
     * Method used to assign values to Order Item Wrapper.
     * Assigns values for both Order and Invoice details page.
     */
    private static OrderItemWrapper assignOrderItemWrapperFields(OrderItem oi, OrderWrapper wrapper){
        OrderItemWrapper oItem = new OrderItemWrapper();  
        oItem.Id = oi.Id;
        //Line Number Order
        oItem.lineNum = oi.NATT_OrderLineNumber__c;
        //Line Number Invoice
        oItem.orderLineNum = oi.NATT_OrderLineNumber__c;

        
        oItem.partNum = oi.Part_Number__c;
        System.debug('Product Name: ' + oItem.description);
        oItem.description = oi.Product2.Name;
        oItem.ordered = oi.Quantity;
        oItem.delivered = oi.NATT_Shipped_Quantity__c;
        oItem.backOrdered = oi.NATT_Backordered_Quantity__c;
        if(oi.NATT_Available_Promise_Date__c != null){
            String dateTimeDelivery = oi.NATT_Available_Promise_Date__c.format();
            oItem.availablePromiseDate = dateTimeDelivery;
        }else{
            oItem.availablePromiseDate = '-';
        }
        oItem.orderItemAmount = oi.AdjustedLineAmount;//(o.UnitPrice * o.Quantity).setScale(2); //Order Table - Amount | Invoice Table - Extended        
        oItem.orderItemPrice = oi.UnitPrice; //Invoice Table - Price
        oItem.amount = oi.AdjustedLineAmount;//o.UnitPrice * o.Quantity; //Used to calculate total
        oItem.status = oi.NATT_Order_Line_Status__c;
        oItem.shipments = oi.Shipment_Items__r.size();
        oItem.shipmentItemAmount=0;
        oItem.unitPrice = oi.UnitPrice;
        for(ShipmentItem si : oi.Shipment_Items__r){
            oItem.shipmentItemAmount += si.NATT_Amount__c;
        }
        wrapper.shippedTotalValue+=oItem.shipmentItemAmount;
        String conversionHold = null;
        if(oi.Product2.NATT_UOM_Conversion__c != null){
            conversionHold = String.valueOf(oi.Product2.NATT_UOM_Conversion__c.intValue());
        }
        oItem.orderItemUOM = conversionHold + ' ' + oi.Product2.QuantityUnitOfMeasure;
        
        return oItem;
    }


    @AuraEnabled(cacheable = true)
    public static List <OrderItem> grabOrderItems (String orderId){
        List <OrderItem> orderItemList = 
            [SELECT 
                Id, 
                Type, 
                TypeCode,
                UnitPrice, 
                TotalPrice,
                Quantity, 
                NATT_OrderLineNumber__c, 
                NATT_Available_Promise_Date__c, 
                NATT_Shipped_Quantity__c,
                NATT_Backordered_Quantity__c, 
                NATT_Order_Line_Status__c,
                NATT_Ship_Date__c,
                Part_Number__c,
                Product2.Id,
                Product2.NATT_P_N__c, 
                Product2.Name, 
                Product2.NATT_UOM_Conversion__c,
                Product2.NATT_Unit__c, 
                Product2.QuantityUnitOfMeasure,
                AdjustedLineAmount,
                (SELECT 
                    Id, 
                    ShipmentId,
                    Quantity,
                    TrackingNumber, 
                    ExpectedDeliveryDate, 
                    ShipmentItemNumber,
                    NATT_OrderProduct__r.NATT_Shipped_Quantity__c,
                    NATT_OrderProduct__r.Quantity,
                    NATT_Amount__c,
                    Product2.NATT_P_N__c, 
                    Product2.Name, 
                    Product2.NATT_Unit__c,
                    Product2.NATT_UOM_Conversion__c,
                    Shipment.NATT_InvoiceNumber__c, 
                    Shipment.NATT_DateShipped__c, 
                    Shipment.NATT_PackingSlipNumber__c,
                    Shipment.TrackingNumber,
                    Shipment.NATT_BillOfLading__c
                FROM Shipment_Items__r)
            FROM OrderItem 
            WHERE OrderID =:orderId 
            ORDER BY NATT_OrderLineNumber__c];
        return orderItemList;
    }

    @AuraEnabled(cacheable = true)
    public static Order grabOrder (String orderId){
        return [SELECT Id, 
        OrderNumber,
        TotalAdjustedDeliveryAmount,
        TotalTaxAmount,
        TotalProductAdjDistAmount, 
        GrandTotalAmount,
        NATT_CustomerName__c,
        NATT_Contact_Name__c,
        NATT_CustomerBilltoCode__c,
        shippingStreet,
        shippingCity,
        shippingCountry,
        shippingState,
        shippingPostalCode,
        NATT_Payment_Instruction__c
        FROM Order
        WHERE ID = :orderId];
    }

    // @AuraEnabled(cacheable = true)
    // public static List <Shipment> getShipment(String orderId){
    //     try {
    //         List <Shipment> s = 
    //          [SELECT Id,NATT_Order__c,NATT_Order__r.NATT_CustomerName__c,NATT_Order__r.NATT_Contact_Name__c,
    //         NATT_Order__r.NATT_CustomerBilltoCode__c,NATT_Order__r.NATT_Contact_Email__c,NATT_Order__r.NATT_Purchase_Order__c,
    //         NATT_Order__r.NATT_Contact_Phone__c,NATT_Order__r.NATT_JDE_Sales_Order_Number__c,NATT_Order__r.OrderedDate,
    //         NATT_Order__r.NATT_JdeOrderTypeName__c,NATT_Order__r.NATT_Warehouse__c,toLabel(NATT_Order__r.NATT_Shipment_Method__c),
    //         NATT_Order__r.ShippingAddress,NATT_Order__r.BillingAddress,toLabel(NATT_Order__r.NATT_Shipment_Terms__c),
    //         NATT_Order__r.NATT_Freight_Account_Number__c,NATT_PackingSlipNumber__c,NATT_ShippingCompanyName__c,NATT_BillOfLading__c,
    //         NATT_InvoiceDate__c,TrackingNumber,
    //         ExpectedDeliveryDate,NATT_InvoiceNumber__c,NATT_Order__r.OrderNumber,NATT_DateShipped__c,NATT_Payment_Captured__c,NATT_Order__r.NATT_Payment_Instruction__c,
    //         (SELECT Id,             
    //                 ShipmentId,
    //                 Quantity,
    //                 TrackingNumber, 
    //                 ExpectedDeliveryDate, 
    //                 ShipmentItemNumber,
    //                 NATT_OrderProduct__c,
    //                 NATT_Amount__c,
    //                 NATT_OrderProduct__r.NATT_OrderLineNumber__c,
    //                 NATT_OrderProduct__r.NATT_Shipped_Quantity__c,
    //                 NATT_OrderProduct__r.Quantity,
    //                 NATT_OrderProduct__r.Part_Number__c,
    //                 NATT_OrderProduct__r.UnitPrice,
    //                 NATT_OrderProduct__r.AdjustedLineAmount,            
    //                 NATT_OrderProduct__r.Product2.NATT_P_N__c, 
    //                 NATT_OrderProduct__r.Product2.Name, 
    //                 NATT_OrderProduct__r.Product2.NATT_Unit__c,
    //                 NATT_OrderProduct__r.Product2.NATT_UOM_Conversion__c,
    //                 NATT_OrderProduct__r.Product2.QuantityUnitOfMeasure,
    //                 NATT_OrderProduct__r.Type,
    //                 NATT_OrderProduct__r.TypeCode,
    //                 Shipment.NATT_InvoiceNumber__c, 
    //                 Shipment.NATT_DateShipped__c, 
    //                 Shipment.NATT_PackingSlipNumber__c,
    //                 Shipment.TrackingNumber,
    //                 Shipment.NATT_BillOfLading__c 
    //             FROM ShipmentItems)
    //         FROM Shipment WHERE NATT_Order__c=:orderId];
    //         System.debug('getShipmentValue: ' + s);
    //         return s;
    //     } catch (Exception e) {
    //         throw new AuraHandledException(e.getMessage());
    //     }
    // }

    // @AuraEnabled(cacheable = true)
    // public static Shipment getShipmentInvoice(String shipmentId){
    //     try {
    //         Shipment s = 
    //          [SELECT Id,NATT_Order__c,NATT_Order__r.NATT_CustomerName__c,NATT_Order__r.NATT_Contact_Name__c,
    //         NATT_Order__r.NATT_CustomerBilltoCode__c,NATT_Order__r.NATT_Contact_Email__c,NATT_Order__r.NATT_Purchase_Order__c,
    //         NATT_Order__r.NATT_Contact_Phone__c,NATT_Order__r.NATT_JDE_Sales_Order_Number__c,NATT_Order__r.OrderedDate,
    //         NATT_Order__r.NATT_JdeOrderTypeName__c,NATT_Order__r.NATT_Warehouse__c,toLabel(NATT_Order__r.NATT_Shipment_Method__c),
    //         NATT_Order__r.ShippingAddress,NATT_Order__r.BillingAddress,toLabel(NATT_Order__r.NATT_Shipment_Terms__c),
    //         NATT_Order__r.NATT_Freight_Account_Number__c,NATT_PackingSlipNumber__c,NATT_ShippingCompanyName__c,NATT_BillOfLading__c,
    //         NATT_InvoiceDate__c,TrackingNumber,
    //         ExpectedDeliveryDate,NATT_InvoiceNumber__c,NATT_Order__r.OrderNumber,NATT_DateShipped__c,NATT_Payment_Captured__c,NATT_Order__r.NATT_Payment_Instruction__c,
    //         (SELECT Id,             
    //         ShipmentId,
    //         Quantity,
    //         TrackingNumber, 
    //         ExpectedDeliveryDate, 
    //         ShipmentItemNumber,
    //         NATT_OrderProduct__c,
    //         NATT_Amount__c,
    //         NATT_OrderProduct__r.NATT_OrderLineNumber__c,
    //         NATT_OrderProduct__r.NATT_Shipped_Quantity__c,
    //         NATT_OrderProduct__r.Quantity,
    //         NATT_OrderProduct__r.Part_Number__c,
    //         NATT_OrderProduct__r.UnitPrice,
    //         NATT_OrderProduct__r.AdjustedLineAmount,            
    //         NATT_OrderProduct__r.Product2.NATT_P_N__c, 
    //         NATT_OrderProduct__r.Product2.Name, 
    //         NATT_OrderProduct__r.Product2.NATT_Unit__c,
    //         NATT_OrderProduct__r.Product2.NATT_UOM_Conversion__c,
    //         NATT_OrderProduct__r.Product2.QuantityUnitOfMeasure,
    //         NATT_OrderProduct__r.Type,
    //         NATT_OrderProduct__r.TypeCode,
    //         Shipment.NATT_InvoiceNumber__c, 
    //         Shipment.NATT_DateShipped__c, 
    //         Shipment.NATT_PackingSlipNumber__c,
    //         Shipment.TrackingNumber,
    //         Shipment.NATT_BillOfLading__c FROM ShipmentItems ORDER BY NATT_OrderProduct__r.NATT_OrderLineNumber__c)
    //          FROM Shipment WHERE Id=:shipmentId];

    //         return s;
    //     } catch (Exception e) {
    //         throw new AuraHandledException(e.getMessage());
    //     }
    // }

    @AuraEnabled(cacheable = true)
    public static List <Order> grabMyOrders (String UserId, String CommunityId){
        String webstoreId = B2BUtils.resolveCommunityIdToWebstoreId(CommunityId);
        return 
        [SELECT 
        Id, 
        OrderNumber,
        RecordTypeId,
        AccountId,
        NATT_Account_Name__c,
        TotalAmount,
        EffectiveDate,
        NATT_Order_Status__c,
        Status,
        SalesStoreId,
        ShippingAddress,
        GrandTotalAmount,
        NATT_Number_of_Order_Products__c,
        NATT_Number_of_Units_Ordered__c,
        NATT_Payment_Instruction__c
        FROM Order
        WHERE ownerId = :UserId AND SalesStoreId = :webstoreId
        ORDER BY OrderNumber DESC
        ];
    }

}