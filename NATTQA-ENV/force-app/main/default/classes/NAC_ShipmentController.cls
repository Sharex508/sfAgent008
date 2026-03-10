public without sharing class NAC_ShipmentController {
    
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
            @AuraEnabled public Decimal invoiceNum {get;set;}
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
                OrderItemWrapper oItemWrapper = assignOrderItemWrapperFields(oi, wrapper);
                Decimal amountHold = 0;
                orderItemList.add(oItemWrapper);
            }
    
            //Query shipment objects for Shipment column in Order Lines
            List < Shipment > shpmnts = [SELECT Id, NATT_InvoiceNumber__c, NATT_PackingSlipNumber__c, NATT_DateShipped__c, NATT_ShippingCompanyName__c,
                TrackingNumber, NATT_BillOfLading__c FROM Shipment WHERE NATT_Order__c =: recordId];
                
            wrapper.shipments = shpmnts;
            wrapper.orderItems = orderItemList;
            wrapper.orderTotal = wrapper.orderTotalValue;
           
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
            oItem.partNum = oi.Product2.ProductCode;
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
            
            oItem.orderItemPrice = oi.UnitPrice; //Invoice Table - Price
            oItem.amount = oi.AdjustedLineAmount;//o.UnitPrice * o.Quantity; //Used to calculate total
            oItem.status = oi.Product2.ProductCode !='FREIGHT-NAOCAP'? oi.NATT_Order_Line_Status__c :'' ;
            oItem.orderItemAmount = oi.AdjustedLineAmount;
            if(oi.Product2.ProductCode !='FREIGHT-NAOCAP'){
                oItem.shipments = oi.Shipment_Items__r.size();
                //(o.UnitPrice * o.Quantity).setScale(2); //Order Table - Amount | Invoice Table - Extended        
            }
            
            
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
        private static List <OrderItem> grabOrderItems (String orderId){
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
                    Part_Number__c,
                    Product2.Id,
                    Product2.NATT_P_N__c, 
                    Product2.Name, 
                    Product2.NATT_UOM_Conversion__c,
                    Product2.NATT_Unit__c, 
                    Product2.QuantityUnitOfMeasure,
                    Product2.ProductCode,
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
        
        /**
         * Grabs individual items for each shipment when shipment is clicked on in Order Line table
         */
        @AuraEnabled
        public static ShipmentItemWrapper fetchShipmentItems(String recordId) {
            ShipmentItemWrapper wrapper = new ShipmentItemWrapper();
            OrderItem orderline = [SELECT Id, Product2.ProductCode, Product2.Name, (Select Id, Shipment.NATT_DateShipped__c, Shipment.NATT_InvoiceNumber__c,
                NATT_OrderProduct__r.Quantity, Quantity, NATT_Amount__c, Shipment.NATT_PackingSlipNumber__c, Shipment.TrackingNumber,Shipment.NATT_ShippingCompanyName__c,
                Shipment.NATT_BillOfLading__c from Shipment_Items__r) FROM OrderItem WHERE Id =: recordId];
            wrapper.partNum = orderline.Product2.ProductCode;
            wrapper.description = orderline.Product2.Name;
            wrapper.shipmentItems = orderline.Shipment_Items__r;
            system.debug(orderline.Shipment_Items__r[0].Shipment.NATT_DateShipped__c);
            return wrapper;
        }

         /**
         * Grabs individual items for each shipment when shipment is clicked on in Shipments Table
         */
        @AuraEnabled
        public static ShipmentItemWrapper fetchShipmentItemList(String recordId) {
            ShipmentItemWrapper wrapper = new ShipmentItemWrapper();            
            List<ShipmentItem> shipmentItemList =[Select Id, Shipment.NATT_DateShipped__c, Shipment.NATT_InvoiceNumber__c,
            NATT_OrderProduct__r.Quantity, Quantity, NATT_Amount__c, Shipment.NATT_PackingSlipNumber__c, Shipment.TrackingNumber,Shipment.NATT_ShippingCompanyName__c,
            Shipment.NATT_BillOfLading__c,NATT_OrderProduct__r.NATT_Shipped_Quantity__c,NATT_P_N__c,NATT_Product_Name__c from ShipmentItem Where ShipmentId =:recordId and NATT_Product_Name__c !='FREIGHT-NAOCAP'];
             
            wrapper.invoiceNum = shipmentItemList[0].Shipment.NATT_InvoiceNumber__c;
            wrapper.shipmentItems = shipmentItemList;            
            return wrapper;
        }
}