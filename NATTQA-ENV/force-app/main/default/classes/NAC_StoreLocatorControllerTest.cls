/**********************************************************************************************
Class name       :  NAC_StoreLocatorControllerTest              
Author           :  
Description      :  Test Class for NAC_StoreLocatorController
*************************************************************************************************/

@isTest
public class NAC_StoreLocatorControllerTest {
    
    static Id serviceStoreRecordTypeId =  Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('CONTAINER_Authorized_Service_Provider').getRecordTypeId();
    @testSetup
    public static void setupTestData(){
        List<Account> accList = NAC_TestDataFactory.createAccounts(7);
        accList[0].RecordTypeId = serviceStoreRecordTypeId;
        accList[0].CONTAINER_X24hr_Service_Number__c = '1234567890';
        accList[0].CONTAINER_Service_Center_Geolocation__Latitude__s = 33.833444;
        accList[0].CONTAINER_Service_Center_Geolocation__Longitude__s = -84.373632;
        accList[0].CONTAINER_Service_Location_Type__c = 'Premium Service Center';
        
        accList[1].RecordTypeId = serviceStoreRecordTypeId;
        accList[1].CONTAINER_Service_Center_Geolocation__Latitude__s = 33.833444;
        accList[1].CONTAINER_Service_Center_Geolocation__Longitude__s = -84.1718;
        accList[1].CONTAINER_Service_Location_Type__c = 'Advanced Service Center';
        
        accList[2].RecordTypeId = serviceStoreRecordTypeId;
        accList[2].CONTAINER_Service_Center_Geolocation__Latitude__s = 32.833444;
        accList[2].CONTAINER_Service_Center_Geolocation__Longitude__s = -84.373632;
        accList[2].CONTAINER_Service_Location_Type__c = 'Service Center';
        
        accList[3].RecordTypeId = serviceStoreRecordTypeId;
        accList[3].CONTAINER_Service_Center_Geolocation__Latitude__s = 33.833444;
        accList[3].CONTAINER_Service_Center_Geolocation__Longitude__s = -83.1718;
        accList[3].CONTAINER_Service_Location_Type__c = 'Parts Depot';
        
        accList[4].RecordTypeId = serviceStoreRecordTypeId;
        accList[4].CONTAINER_Service_Center_Geolocation__Latitude__s = 33.833444;
        accList[4].CONTAINER_Service_Center_Geolocation__Longitude__s = -85.373632;
        accList[4].CONTAINER_Service_Location_Type__c = 'Premium Support Center';
        
        accList[5].RecordTypeId = serviceStoreRecordTypeId;
        accList[5].CONTAINER_Service_Center_Geolocation__Latitude__s = 33.1812;
        accList[5].CONTAINER_Service_Center_Geolocation__Longitude__s = -85.1718;
        accList[5].CONTAINER_Service_Location_Type__c = 'Container Service Center';
        
        accList[6].RecordTypeId = serviceStoreRecordTypeId;
        accList[6].CONTAINER_Service_Center_Geolocation__Latitude__s = 32.833444;
        accList[6].CONTAINER_Service_Center_Geolocation__Longitude__s = -83.373632;
        accList[6].CONTAINER_Service_Location_Type__c = 'Repair Center';
        insert accList;
    }
    
    @isTest
    public static void findNearbyStore_Positive_Test(){
        String searchKey = '38006';
        String searchRadius = '300';
        Map<Id,Account> accountIdMap = new Map<Id,Account>([SELECT ID FROM Account WHERE RecordTypeId =: serviceStoreRecordTypeId]);
        Test.setMock(HttpCalloutMock.class, new NAC_TestDataFactory.calloutPostiveResponses());
        test.startTest();
        list<NAC_StoreLocatorController.serviceCenterWrapper> scWrapList = NAC_StoreLocatorController.findNearbyStore(searchKey,searchRadius);
        test.stopTest();
        for(NAC_StoreLocatorController.serviceCenterWrapper scWrap : scWrapList){
            for(NAC_StoreLocatorController.LocationWrapper locWrappers : scWrap.distributorLocWrapList){
                system.assert(accountIdMap.keySet().contains(locWrappers.id));
            }
        }
    }
    
    @isTest
    public static void findNearbyStore_Negative_Test_1(){
        String searchKey = '30318';
        String searchRadius = '100';
        Set<Id> accountIdSet = new Set<Id>();
        List<Account> accList = [SELECT ID FROM Account WHERE RecordTypeId =: serviceStoreRecordTypeId];
        for(Integer i=0; i<accList.size(); i++){
            accList[i].CONTAINER_Service_Center_Geolocation__Latitude__s = 41.8781 + i;
            accList[i].CONTAINER_Service_Center_Geolocation__Longitude__s = 87.6298 + i;
        }
        update accList;
        Test.setMock(HttpCalloutMock.class, new NAC_TestDataFactory.calloutPostiveResponses());
        test.startTest();
        list<NAC_StoreLocatorController.serviceCenterWrapper> scWrapList = NAC_StoreLocatorController.findNearbyStore(searchKey,searchRadius);
        test.stopTest();
        List<NAC_StoreLocatorController.LocationWrapper> checkLocWrapList = new List<NAC_StoreLocatorController.LocationWrapper>();
        for(NAC_StoreLocatorController.serviceCenterWrapper scWrap : scWrapList){
            for(NAC_StoreLocatorController.LocationWrapper locWrappers : scWrap.distributorLocWrapList){
                checkLocWrapList.add(locWrappers);
            }
        }
        system.assert(checkLocWrapList.isEmpty());
    }
    
    @isTest
    public static void findNearbyStore_Negative_Test_2(){
        String searchKey = '30318';
        String searchRadius = '100';
        test.startTest();
        try{
            list<NAC_StoreLocatorController.serviceCenterWrapper> scWrapList = NAC_StoreLocatorController.findNearbyStore(searchKey,searchRadius);
            system.assert(false);
        }catch(Exception e){
            system.assert(e.getMessage().contains('Error FROM NAC_StoreLocatorController.findNearbyStore'));
        }
        test.stopTest();
    }
    
}