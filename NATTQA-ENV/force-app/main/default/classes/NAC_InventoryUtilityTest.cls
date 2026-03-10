@isTest
public class NAC_InventoryUtilityTest {
@isTest
    static void getProductAvailabilityTest(){
       Product2 prod = new Product2(Name ='testProd'+Math.random(),
                                     StockkeepingUnit ='SKU'+Math.random()                            
                                    );
       insert prod;
       List<String> pIds=new List<String>();
       pIds.add(prod.id);
       NATT_ProductInventoryItem__c prodInventory=NAC_TestDataFactory.createProdInventory(prod,NAC_Global_Constants.WAREHOUSEDEF);
       insert prodInventory;
        
       Test.startTest();
       NATT_ProductInventoryItem__c nic=NAC_InventoryUtility.getProductAvailability(prod.id,NAC_Global_Constants.WAREHOUSEDEF);
       Map<Id, NATT_ProductInventoryItem__c> mapOfAvailability=NAC_InventoryUtility.getCartAvailability(pIds,NAC_Global_Constants.WAREHOUSEDEF);
       Map<String,NATT_ProductInventoryItem__c> mapOfPavailbity=NAC_InventoryUtility.getAllWarehouseAvailability(prod.id);	
       Test.stopTest();
       System.assertNotEquals(nic, null, 'Product is not there in the inventory');
       System.assertNotEquals(mapOfAvailability.isEmpty(), true, 'Product is not there in the inventory');
       System.assertNotEquals(mapOfPavailbity.isEmpty(), true, 'Product is not there in the inventory');
    }
}