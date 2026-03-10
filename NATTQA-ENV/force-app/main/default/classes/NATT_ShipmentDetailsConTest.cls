@IsTest
private class NATT_ShipmentDetailsConTest {
    @IsTest
    static void callSoqlQuery(){
        Id NATT_Parts_Order_RT = Schema.SObjectType.Shipment.getRecordTypeInfosByDeveloperName().get('NATT_Parts_Shipment').getRecordTypeId();
        Shipment s = new Shipment(ShipToName='Test');
        s.RecordTypeId = NATT_Parts_Order_RT;
        s.NATT_ShippingCompanyName__c = 'ABF FREIGHT';
        insert s;
        NATT_ShipmentDetailsCon.getShipment(s.Id);
        NATT_ShipmentDetailsCon.getTrackinginfo(s.Id);
    }
}