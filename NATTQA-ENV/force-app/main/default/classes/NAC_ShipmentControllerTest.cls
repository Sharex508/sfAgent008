@IsTest
public class NAC_ShipmentControllerTest {
  @isTest
    static void fetchShipmentItemsTest(){
        Account acc=NAC_TestDataFactory.insertAccount();
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc); 

       Order ord= NAC_TestDataFactory.createOrder(con.id,acc.id,'');
       OrderItem odItem=[select id,Product2Id, OrderId from orderItem where OrderId=:ord.id LIMIT 1];
        
      Shipment sh=NAC_TestDataFactory.createShipment(ord.id);
      insert sh;
        
      ShipmentItem shm=NAC_TestDataFactory.createShipmentitem(sh.id,odItem);
      insert shm;
         
      Test.startTest();
       NAC_ShipmentController.ShipmentItemWrapper shp= NAC_ShipmentController.fetchShipmentItems(odItem.id);
      Test.stopTest();
       system.assertEquals(shp.partNum, null, 'soemthing went wrong when trying to create a shipment for this');
    }
    @isTest
    static void fetchOrderlinesTest(){
        Account acc=NAC_TestDataFactory.insertAccount();
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc); 

       Order ord= NAC_TestDataFactory.createOrder(con.id,acc.id,'');
       OrderItem odItem=[select id,Product2Id, OrderId from orderItem where OrderId=:ord.id LIMIT 1];

       Shipment sh=NAC_TestDataFactory.createShipment(ord.id);
       insert sh;
        
       ShipmentItem shm=NAC_TestDataFactory.createShipmentitem(sh.id,odItem);
       insert shm;
        
       Test.startTest();
       NAC_ShipmentController.OrderWrapper odp= NAC_ShipmentController.fetchOrderlines(ord.id);
       Test.stopTest();
       system.assertNotEquals(odp.id, null, 'soemthing went wrong when trying to create an order');
    }
}