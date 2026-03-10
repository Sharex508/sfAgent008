public without sharing class NATT_orderDetailsController {

    /**
     * Wrapper classs that are used to store Order and Invoice page data.
     */
    public Class OrderWrapper {
        @AuraEnabled public List < OrderItemWrapper > orderItems{get;set;}
        @AuraEnabled public List < Shipment > shipments {get;set;}
        @AuraEnabled public Decimal partTotal {get;set;}
        @AuraEnabled public Decimal freightTotal {get;set;}
        @AuraEnabled public Decimal rushOrderTotal {get;set;}
        @AuraEnabled public Decimal orderTotal {get;set;}
        @AuraEnabled public Decimal partTotalValue {get;set;}
        @AuraEnabled public Decimal freightTotalValue {get;set;}
        @AuraEnabled public Decimal rushOrderTotalValue {get;set;}
        @AuraEnabled public Decimal orderTotalValue {get;set;}
        @AuraEnabled public Decimal shippedTotalValue {get;set;}
        @AuraEnabled public String Id {get;set;}
       // @AuraEnabled public String TrackingNumberNew {get;set;}
        @AuraEnabled public Map<String,String> TrackingNumberNew {get;set;}

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
        @AuraEnabled public String unitOfMeasure {get;set;}
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
    
     public Class ShipmentItemWrapper {
        @AuraEnabled public String partNum {get;set;}
        @AuraEnabled public String description {get;set;}
        @AuraEnabled public List < ShipmentItem > shipmentItems {get;set;}
    }

    /**
     * Method used to grab data for Order Lines section of Order Details page.
     * Grabs a list of Order Items and populates a OrderItemWrapper.
     * OrderItemWrapper is stored in OrderWrapper, which is cycled through on details page.
     */
    @AuraEnabled(cacheable = true)
    public static OrderWrapper fetchOrderlines(String recordId) {
        List < OrderItemWrapper > orderItemList = new List < OrderItemWrapper >();
        OrderWrapper wrapper = wrapperCreation('Order Total Values');
        
        //method used to grab orderitems (products) for invoice
        List <OrderItem> orderLines = grabOrderItems(recordId);
        
        for(OrderItem oi : orderlines){
            if(oi.TypeCode=='Charge' && oi.Type=='Delivery Charge'){ 
                //Freight Product 
                if(oi.Product2.Name.contains('Freight')){
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
        Map<String, Id> mapShippingcompany = new Map<String, Id>();
        for(Shipment sh : shpmnts){
           mapShippingcompany.put(sh.NATT_ShippingCompanyName__c, sh.Id); 
            }
        system.debug('shpmnts ---- > '+shpmnts);
        List<NATT_Tracking__mdt> lstTrack = new List<NATT_Tracking__mdt>();
        Map<String,String> mapTrack = new Map<String,String>();
        if(mapShippingcompany != null){
            lstTrack = [select NATT_ShippingCompanyURL__c,ShippingCompanyName__c FROM NATT_Tracking__mdt where ShippingCompanyName__c IN: mapShippingcompany.keySet()];
        }   

        for(NATT_Tracking__mdt lst: lstTrack){
            mapTrack.put(lst.ShippingCompanyName__c,lst.NATT_ShippingCompanyURL__c);
        }
           
        wrapper.shipments = shpmnts;
        wrapper.orderItems = orderItemList;
        wrapper.partTotal = (wrapper.partTotalValue);
        wrapper.freightTotal = (wrapper.freightTotalValue);
        wrapper.rushOrderTotal = (wrapper.rushOrderTotalValue);
        //wrapper.orderTotal = (orderInfo.TotalAmount);
        wrapper.orderTotal = wrapper.orderTotalValue;
        if(lstTrack != null && !lstTrack.isempty()){
            wrapper.TrackingNumberNew = mapTrack;
        }
        else {
            wrapper.TrackingNumberNew = null;
        }
        return wrapper;
    }

    /**
     * Method used to grab data for Parts Details section of Invoice page.
     * Grabs a list of Order Items and populates a OrderItemWrapper.
     * OrderItemWrapper is stored in OrderWrapper, which is cycled through on details page.
     */
    @AuraEnabled
    public static OrderWrapper fetchInvoiceInformation(String shipmentId){
        List < OrderItemWrapper > orderItemList = new List < OrderItemWrapper >();
        List <Order> orderList = new List <Order>();
        
        Shipment shipmentInfo = [SELECT Id, NATT_InvoiceNumber__c, NATT_PackingSlipNumber__c, NATT_DateShipped__c, NATT_ShippingCompanyName__c,
                                        TrackingNumber, NATT_BillOfLading__c, NATT_Order__c
                                        FROM Shipment 
                                        WHERE Id = :shipmentId];

        /*List <ShipmentItem> shipmentItemDetail = [SELECT NATT_Amount__c, Quantity, NATT_OrderProduct__c 
                                        FROM ShipmentItem 
                                        WHERE ShipmentId = :shipmentInfo.Id];*/

        OrderWrapper wrapper = wrapperCreation('Invoice Total Values');
        
        //method used to grab orderitems (products) for invoice
        List <OrderItem> orderLines = grabOrderItems(shipmentInfo.NATT_Order__c);
        
        for(OrderItem o : orderlines){
            for(ShipmentItem shipItm : o.Shipment_Items__r){
                if(shipItm.ShipmentId == shipmentInfo.Id ){
                    if(o.TypeCode=='Charge' && o.Type=='Delivery Charge'){
                        //Freight Product for Total
                        if(o.Product2.Name.contains('Freight') ){                            
                            wrapper.freightTotalValue += o.UnitPrice;
                            continue;
                        }
                        //Rush Fee Product for Total
                        if(o.Product2.Name.contains('Rush Fee') || o.NATT_OrderLineNumber__c == 990){                    
                            wrapper.rushOrderTotalValue += o.UnitPrice;
                            continue;
                        }
                    }
                    OrderItemWrapper oItem = assignOrderItemWrapperFields(o, wrapper);
                    Decimal amountHold = 0;
                    
                    //Invoice Specific fields that require shipment item fields
                    oItem.trackingNumber = shipItm.TrackingNumber;
                    if(shipItm.ExpectedDeliveryDate != null){
                        String dateTimeDelivery = shipItm.ExpectedDeliveryDate.format('MM/dd/yyyy');
                        oItem.expectedDelivery = dateTimeDelivery;
                    }
                    oItem.shipItemNum = shipItm.ShipmentItemNumber;
                    
                    orderItemList.add(oItem);   
                    wrapper.partTotalValue += oItem.amount;
                    wrapper.orderTotalValue += (wrapper.rushOrderTotalValue + oItem.amount); //totalamount
                    System.debug('OrderItemValue: ' + oItem);
                }
            }     
        }
        wrapper.orderItems = orderItemList; 
        wrapper.partTotal = (wrapper.partTotalValue);
        wrapper.freightTotal = (wrapper.freightTotalValue);
        wrapper.rushOrderTotal = (wrapper.rushOrderTotalValue);
        wrapper.orderTotal = (wrapper.orderTotalValue);         
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
        oItem.lineNum = oi.NATT_OrderBy__c;
        //Line Number Invoice
        oItem.orderLineNum = oi.NATT_OrderBy__c;

        
        oItem.partNum = oi.Part_Number__c;
        oItem.description = oi.Product2.Name;
        oItem.ordered = oi.Quantity;
        oItem.delivered = oi.NATT_Shipped_Quantity__c;
        oItem.backOrdered = oi.NATT_Backordered_Quantity__c;
        oItem.unitOfMeasure = oi.NATT_QuantityUOM__c;
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
       // oItem.orderItemUOM = conversionHold + ' ' + oi.Product2.QuantityUnitOfMeasure;
        oItem.unitOfMeasure = conversionHold + ' ' + oi.Product2.QuantityUnitOfMeasure;
        return oItem;
       
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
     * Queries List of Products (OrderItems) related to the order.
     */
    // added NATT_QuantityUOM__c field for CXREF-4855
    private static List <OrderItem> grabOrderItems (String orderId){
        List <OrderItem> orderItemList = 
        [SELECT 
        Id, 
        Type, 
        TypeCode,
        UnitPrice, 
        TotalPrice,
        Quantity, 
        NATT_OrderBy__c, 
        NATT_Available_Promise_Date__c, 
        NATT_Shipped_Quantity__c,
        NATT_Backordered_Quantity__c, 
        NATT_OrderLineNumber__c,
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
        NATT_QuantityUOM__c,
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
            ORDER BY NATT_OrderBy__c];
            system.debug('Orderline list---->' +orderItemList);

        return orderItemList;
    }
    
    /**
     * Grabs individual items for each shipment when shipment is clicked on in Order Line table
     */
    @AuraEnabled
    public static ShipmentItemWrapper fetchShipmentItems(String recordId) {
        ShipmentItemWrapper warpper = new ShipmentItemWrapper();
        OrderItem orderline = [SELECT Id, Product2.NATT_P_N__c, Product2.Name, (Select Id, Shipment.NATT_DateShipped__c, Shipment.NATT_InvoiceNumber__c,
            NATT_OrderProduct__r.Quantity, Quantity, NATT_Amount__c, Shipment.NATT_PackingSlipNumber__c, Shipment.TrackingNumber,Shipment.NATT_ShippingCompanyName__c,
            Shipment.NATT_BillOfLading__c from Shipment_Items__r) FROM OrderItem WHERE Id  =: recordId];
        warpper.partNum = orderline.Product2.NATT_P_N__c;
        warpper.description = orderline.Product2.Name;
        warpper.shipmentItems = orderline.Shipment_Items__r;
        system.debug(orderline.Shipment_Items__r[0].Shipment.NATT_DateShipped__c);
        System.debug('Shipment Wrapper: ' + warpper);
        return warpper;
    }
    
    /**
     * Grabs Shipments to be displayed in Order Lines table
     * 
     
    @AuraEnabled
    public static List < Shipment > fetchShipments(String recordId) {
        List < Shipment > shpmnts = [Select Id, NATT_InvoiceNumber__c, NATT_PackingSlipNumber__c, NATT_DateShipped__c, NATT_ShippingCompanyName__c,
            TrackingNumber, NATT_BillOfLading__c from Shipment where NATT_Order__c =: recordId ORDER BY NATT_InvoiceNumber__c];
            
        return shpmnts;
    }*/


}