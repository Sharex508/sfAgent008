public with sharing class NATT_ArticleCarouselRecentlyController {
    
    @AuraEnabled
    public static Map<String, Object> getRecentlyModifiedArticles() {
        List<Knowledge> ltKnowledge = new List<NATT_ArticleCarouselRecentlyController.Knowledge>();
        Map<String, Object> mpReturn = new Map<String, Object>{'success' => true, 'message' => '', 'isAccessible' => true};
        String status = 'Online';

        try {

            if (!NATT_Utils.isAccessible('Knowledge__kav')) {
                mpReturn.put('isAccessible', false);
                throw new AuraHandledException('Not able to access this content.');
            }

            for (Knowledge__kav knowledge : [SELECT Id, Title, Summary, CreatedDate, LastPublishedDate, UrlName, NATT_General_Bulletin__c, NATT_Parts_Bulletin__c, NATT_Service_Bulletin__c, NATT_Training_Bulletin__c, 
                                             NATT_Product_Manual_Updates__c, NATT_Dealer_News__c, NATT_eFlash__c 
                                             FROM Knowledge__kav WHERE PublishStatus = :status AND (NATT_General_Bulletin__c = TRUE OR NATT_Parts_Bulletin__c = TRUE OR NATT_Service_Bulletin__c = TRUE OR 
                                                                                                    NATT_Training_Bulletin__c = TRUE OR NATT_Product_Manual_Updates__c = TRUE OR NATT_Dealer_News__c = TRUE 
                                                                                                    OR NATT_eFlash__c = TRUE) ORDER BY LastModifiedDate DESC LIMIT 15]) {
                Knowledge knowledgeObj = new Knowledge();
                
                String assetName = getKwnowledgeCategorization(knowledge.NATT_General_Bulletin__c, knowledge.NATT_Parts_Bulletin__c, knowledge.NATT_Service_Bulletin__c, knowledge.NATT_Training_Bulletin__c, knowledge.NATT_Product_Manual_Updates__c, knowledge.NATT_Dealer_News__c, knowledge.NATT_eFlash__c);
    
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
            
			if (Test.isRunningTest() && NATT_Utils.isError ) { throw new NATT_Utils.TestException('Error'); }
        } catch (Exception e) {
            mpReturn.put('success', false);            
            mpReturn.put('message', e.getMessage());
        }
        

        return mpReturn;
    }

    private static String getKwnowledgeCategorization(Boolean general, Boolean parts, Boolean service, Boolean training, Boolean product, Boolean news, Boolean eFlash) {
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
        } else if (news) {
            category = 'NATT_dealer_news';            
        } else {
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