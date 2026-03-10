public without sharing class NATT_TesOrderDetailsConShipment {
    @AuraEnabled(cacheable = true)
    public static List <Shipment> getShipment(String orderId){
        try {
            List <Shipment> s = 
             [SELECT Id,NATT_Order__c,NATT_Order__r.NATT_CustomerName__c,NATT_Order__r.NATT_Contact_Name__c,
            NATT_Order__r.NATT_CustomerBilltoCode__c,NATT_Order__r.NATT_Contact_Email__c,NATT_Order__r.NATT_Purchase_Order__c,
            NATT_Order__r.NATT_Contact_Phone__c,NATT_Order__r.NATT_JDE_Sales_Order_Number__c,NATT_Order__r.OrderedDate,
            NATT_Order__r.NATT_JdeOrderTypeName__c,NATT_Order__r.NATT_Warehouse__c,toLabel(NATT_Order__r.NATT_Shipment_Method__c),
            NATT_Order__r.ShippingAddress,NATT_Order__r.BillingAddress,toLabel(NATT_Order__r.NATT_Shipment_Terms__c),
            NATT_Order__r.NATT_Freight_Account_Number__c,NATT_PackingSlipNumber__c,NATT_ShippingCompanyName__c,NATT_BillOfLading__c,
            NATT_InvoiceDate__c,TrackingNumber,
            ExpectedDeliveryDate,NATT_InvoiceNumber__c,NATT_Order__r.OrderNumber,NATT_DateShipped__c,NATT_Payment_Captured__c,NATT_Order__r.NATT_Payment_Instruction__c,
            (SELECT Id,             
                    ShipmentId,
                    Quantity,
                    TrackingNumber, 
                    ExpectedDeliveryDate, 
                    ShipmentItemNumber,
                    NATT_OrderProduct__c,
                    NATT_Amount__c,
                    NATT_OrderProduct__r.NATT_OrderLineNumber__c,
                    NATT_OrderProduct__r.NATT_Shipped_Quantity__c,
                    NATT_OrderProduct__r.Quantity,
                    NATT_OrderProduct__r.Part_Number__c,
                    NATT_OrderProduct__r.UnitPrice,
                    NATT_OrderProduct__r.AdjustedLineAmount,            
                    NATT_OrderProduct__r.Product2.NATT_P_N__c, 
                    NATT_OrderProduct__r.Product2.Name, 
                    NATT_OrderProduct__r.Product2.NATT_Unit__c,
                    NATT_OrderProduct__r.Product2.NATT_UOM_Conversion__c,
                    NATT_OrderProduct__r.Product2.QuantityUnitOfMeasure,
                    NATT_OrderProduct__r.Type,
                    NATT_OrderProduct__r.TypeCode,
                    Shipment.NATT_InvoiceNumber__c, 
                    Shipment.NATT_DateShipped__c, 
                    Shipment.NATT_PackingSlipNumber__c,
                    Shipment.TrackingNumber,
                    Shipment.NATT_BillOfLading__c 
                FROM ShipmentItems)
            FROM Shipment WHERE NATT_Order__c=:orderId];
            System.debug('getShipmentValue: ' + s);
            return s;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable = true)
    public static Shipment getShipmentInvoice(String shipmentId){
        try {
            Shipment s = 
             [SELECT Id,NATT_Order__c,NATT_Order__r.NATT_CustomerName__c,NATT_Order__r.NATT_Contact_Name__c,
            NATT_Order__r.NATT_CustomerBilltoCode__c,NATT_Order__r.NATT_Contact_Email__c,NATT_Order__r.NATT_Purchase_Order__c,
            NATT_Order__r.NATT_Contact_Phone__c,NATT_Order__r.NATT_JDE_Sales_Order_Number__c,NATT_Order__r.OrderedDate,
            NATT_Order__r.NATT_JdeOrderTypeName__c,NATT_Order__r.NATT_Warehouse__c,toLabel(NATT_Order__r.NATT_Shipment_Method__c),
            NATT_Order__r.ShippingAddress,NATT_Order__r.BillingAddress,toLabel(NATT_Order__r.NATT_Shipment_Terms__c),
            NATT_Order__r.NATT_Freight_Account_Number__c,NATT_PackingSlipNumber__c,NATT_ShippingCompanyName__c,NATT_BillOfLading__c,
            NATT_InvoiceDate__c,TrackingNumber,
            ExpectedDeliveryDate,NATT_InvoiceNumber__c,NATT_Order__r.OrderNumber,NATT_DateShipped__c,NATT_Payment_Captured__c,NATT_Order__r.NATT_Payment_Instruction__c,
            (SELECT Id,             
            ShipmentId,
            Quantity,
            TrackingNumber, 
            ExpectedDeliveryDate, 
            ShipmentItemNumber,
            NATT_OrderProduct__c,
            NATT_Amount__c,
            NATT_OrderProduct__r.NATT_OrderLineNumber__c,
            NATT_OrderProduct__r.NATT_Shipped_Quantity__c,
            NATT_OrderProduct__r.Quantity,
            NATT_OrderProduct__r.Part_Number__c,
            NATT_OrderProduct__r.UnitPrice,
            NATT_OrderProduct__r.AdjustedLineAmount,            
            NATT_OrderProduct__r.Product2.NATT_P_N__c, 
            NATT_OrderProduct__r.Product2.Name, 
            NATT_OrderProduct__r.Product2.NATT_Unit__c,
            NATT_OrderProduct__r.Product2.NATT_UOM_Conversion__c,
            NATT_OrderProduct__r.Product2.QuantityUnitOfMeasure,
            NATT_OrderProduct__r.Type,
            NATT_OrderProduct__r.TypeCode,
            Shipment.NATT_InvoiceNumber__c, 
            Shipment.NATT_DateShipped__c, 
            Shipment.NATT_PackingSlipNumber__c,
            Shipment.TrackingNumber,
            Shipment.NATT_BillOfLading__c FROM ShipmentItems ORDER BY NATT_OrderProduct__r.NATT_OrderLineNumber__c)
             FROM Shipment WHERE Id=:shipmentId];

            return s;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}