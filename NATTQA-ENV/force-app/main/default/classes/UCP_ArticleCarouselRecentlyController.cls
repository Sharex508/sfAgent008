public without sharing class UCP_ArticleCarouselRecentlyController {
    
    @AuraEnabled
    public static Map<String, Object> getRecentlyModifiedArticles() {
        List<Knowledge> ltKnowledge = new List<UCP_ArticleCarouselRecentlyController.Knowledge>();
        Map<String, Object> mpReturn = new Map<String, Object>{'success' => true, 'message' => '', 'isAccessible' => true};
        String status = 'Online';

        try {

            if (!NATT_Utils.isAccessible('Knowledge__kav')) {
                mpReturn.put('isAccessible', false);
                throw new AuraHandledException('Not able to access this content.');
            }
			User objUser = [SELECT Id,Name,UCP_Region__c FROM User WHERE Id =:UserInfo.getUserId()];
            for (Knowledge__kav knowledge : [SELECT Id, Title, Summary, CreatedDate, LastPublishedDate, UrlName, NATT_General_Bulletin__c, NATT_Parts_Bulletin__c, NATT_Service_Bulletin__c, NATT_Training_Bulletin__c, 
                                             NATT_Product_Manual_Updates__c, NATT_eFlash__c,UCP_Software_Release__c 
                                             FROM Knowledge__kav WHERE PublishStatus = :status 
                                             AND RecordType.Name = 'UCP Container'
                                             AND (UCP_Region__c	 = 'UCP (Global)' OR UCP_Region__c	 =: objUser.UCP_Region__c)
                                             AND (NATT_General_Bulletin__c = TRUE OR NATT_Parts_Bulletin__c = TRUE OR NATT_Service_Bulletin__c = TRUE OR 
                                                                                                    NATT_Training_Bulletin__c = TRUE OR NATT_Product_Manual_Updates__c = TRUE OR NATT_eFlash__c = TRUE OR UCP_Software_Release__c = TRUE) ORDER BY LastModifiedDate DESC LIMIT 15]) {
                
                                                                                                        
                Knowledge knowledgeObj = new Knowledge();
                
                String assetName = getKwnowledgeCategorization(knowledge.NATT_General_Bulletin__c, knowledge.NATT_Parts_Bulletin__c, knowledge.NATT_Service_Bulletin__c, knowledge.NATT_Training_Bulletin__c, knowledge.NATT_Product_Manual_Updates__c, knowledge.NATT_eFlash__c,knowledge.UCP_Software_Release__c);
                                                                                                        
                                                                                                        
                knowledgeObj.id = knowledge.Id;
                knowledgeObj.title = knowledge.Title;
                knowledgeObj.summary = knowledge.Summary;
                knowledgeObj.url = 'article/' + knowledge.UrlName;
                knowledgeObj.publishedDate = knowledge.LastPublishedDate.format('MMMM dd, yyyy');
                knowledgeObj.image = assetName;
                knowledgeObj.iconType = assetName;
                ltKnowledge.add(knowledgeObj);
            }
	
            mpReturn.put('data', ltKnowledge);
            
            List<Knowledge__kav> knowledge = [SELECT Id FROM Knowledge__kav];
            
			if (Test.isRunningTest() && NATT_Utils.isError ) { throw new NATT_Utils.TestException('Error'); }
        } catch (Exception e) {
            mpReturn.put('success', false);   
            system.debug('message'+e.getMessage());
            mpReturn.put('message', e.getMessage());
        }
        

        return mpReturn;
    }

    private static String getKwnowledgeCategorization(Boolean general, Boolean parts, Boolean service, Boolean training, Boolean product, Boolean eFlash,Boolean softwareRelease) {
        String category = '';

        if (general) {
            category = 'NATT_general_bulletin';
        } else if (parts) {
            category = 'NATT_parts_bulletin';            
        } else if (service) {
            category = 'NATT_service_bulletin';            
        } else if (training) {
            category = 'NATT_training_bulletin';            
        } else if (product) {
            category = 'NATT_product_manual_updates';            
        }  else if(softwareRelease){
            category = 'UCP_Software_Release__c' ;
        }
        else{
            category = 'NATT_eflash';
        }

        return category;
    }

    // wrapper class
    public class Knowledge {
        @AuraEnabled public Id id;
        @AuraEnabled public String title;
        @AuraEnabled public String summary;
        @AuraEnabled public String type;
        @AuraEnabled public String url;
        @AuraEnabled public String publishedDate;
        @AuraEnabled public String image = '';
        @AuraEnabled public String iconType = '';
        
    }

}