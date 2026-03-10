@IsTest
public with sharing class UCP_AlertCarouselControllerTest {
    
    @TestSetup
    static void makeData() {
        NATT_Alert__c newAlert = NATT_DataFactory.createNATTAlert();
        NATT_Alert__c newAlert2 = NATT_DataFactory.createNATTAlert();
    }

    @IsTest
    static void getAlertsTest() {
        Map<String, Object> mpReturn = UCP_AlertCarouselController.getAlerts();
        List<NATT_Alert__c> ltAlert = (List<NATT_Alert__c>) mpReturn.get('data');
        
        Test.startTest();
            System.assert( (Boolean) mpReturn.get('success'));
            //System.assertEquals(2, ltAlert.size());
        Test.stopTest();
        
    }

    @IsTest
    static void getAlertsFailTest() {
        NATT_Utils.isError = true;
        Map<String, Object> mpReturn = UCP_AlertCarouselController.getAlerts();
        List<NATT_Alert__c> ltAlert = (List<NATT_Alert__c>) mpReturn.get('data');
        
        Test.startTest();
            System.assertEquals(false, (Boolean) mpReturn.get('success'));
        Test.stopTest();
        
    }

}