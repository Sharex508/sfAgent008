@isTest
public class NAC_OrderNetworkDetailsTest {
    
@isTest
    static void createTest(){
        Account acc=NAC_TestDataFactory.insertAccount();
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc);
        User us= NAC_TestDataFactory.runAsNACUser();
        Order ord=NAC_TestDataFactory.createOrder(con.id,Acc.id,'');
        ord.Ownerid=us.id;
        Update ord;
        Order ord1=[select id,Ownerid from Order where id=:ord.id];
        Shipment sh=NAC_TestDataFactory.createShipment(ord.id);
        sh.RecordTypeId =Schema.SObjectType.Shipment.getRecordTypeInfosByDeveloperName().get('NAOCAP_Shipment').getRecordTypeId();
      
        insert sh;
    
        List<ID> shList=new List<ID>();
        shList.add(sh.id);
       
        Test.startTest();
        NAC_OrderNetworkDetails.sendEmail(shList);
        Test.stopTest();
    }

}