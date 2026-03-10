public without sharing class UCP_WhosWhoController {
    
    @AuraEnabled
    public static Map<String, Object> getWhosWhoArticle() {
        Map<String, Object> mpReturn = new Map<String, Object>{'success' => true, 'message' => ''};
        String status = 'Online';

        try {     
            User objUser = [SELECT Id,Name,UCP_Region__c,NATT_Whos_Who__c FROM User WHERE Id =:UserInfo.getUserId()];
            
            if(objUser.NATT_Whos_Who__c == true){
                mpReturn.put('data', [SELECT Id, Title, CreatedDate, LastPublishedDate, UrlName FROM Knowledge__kav 
                                      WHERE 
                                        PublishStatus =:status AND 
                                        NATT_Whos_Who__c = true 
                                       AND 
                                        UCP_Region__c=: objUser.UCP_Region__c
                                      LIMIT 1]);
            
                if (Test.isRunningTest() && NATT_Utils.isError ) {
                    throw new NATT_Utils.TestException('Error'); 
                }
            }
            else{
             	mpReturn.put('data','');
        	}
        } 
       
        catch (Exception e) {
            mpReturn.put('success', false);
            mpReturn.put('message', e.getMessage());
            
        }
        return mpReturn;
    }
}