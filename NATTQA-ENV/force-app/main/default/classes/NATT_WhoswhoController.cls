public without sharing class NATT_WhoswhoController {
    
    @AuraEnabled
    public static Map<String, Object> getWhosWhoArticle() {
        Map<String, Object> mpReturn = new Map<String, Object>{'success' => true, 'message' => ''};
        String status = 'Online';

        try {            
            mpReturn.put('data', [SELECT Id, Title, CreatedDate, LastPublishedDate, UrlName FROM Knowledge__kav WHERE PublishStatus =:status AND NATT_Whos_Who__c = true LIMIT 1]);
        
            if (Test.isRunningTest() && NATT_Utils.isError ) { throw new NATT_Utils.TestException('Error'); }
        } catch (Exception e) {
            mpReturn.put('success', false);
            mpReturn.put('message', e.getMessage());
        }

        return mpReturn;
    }
}