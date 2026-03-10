public with sharing class NATT_AlertCarouselController {
    
    @AuraEnabled
    public static Map<String, Object> getAlerts() {
        Map<String, Object> mpReturn = new Map<String, Object>{'success' => true, 'message' => ''};

        try {            
            mpReturn.put('data', [SELECT Id, NATT_AlertText__c FROM NATT_Alert__c WHERE NATT_Start_Date__c <= TODAY AND NATT_End_Date__c >= TODAY ORDER BY CreatedDate DESC]);
        
            if (Test.isRunningTest() && NATT_Utils.isError ) { throw new NATT_Utils.TestException('Error'); }
        } catch (Exception e) {
            mpReturn.put('success', false);
            mpReturn.put('message', e.getMessage());
        }

        return mpReturn;
    }

}