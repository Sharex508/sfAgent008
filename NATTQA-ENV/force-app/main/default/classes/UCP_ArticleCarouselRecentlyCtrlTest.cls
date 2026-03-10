@IsTest
public without sharing class UCP_ArticleCarouselRecentlyCtrlTest {
    
    @TestSetup
    static void makeData(){
        
        Id recordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Knowledge__kav' AND Name = 'UCP Container' LIMIT 1].Id;

        Knowledge__kav knowObj1 = new Knowledge__kav(
            Title = 'Article Test 1',
            UrlName = 'article-test-1',
            recordTypeId = recordTypeId
        );
        Insert knowObj1;
        
        Knowledge__kav knowObj2 = new Knowledge__kav(
            Title = 'Article Test 2',
            UrlName = 'article-test-2',
            recordTypeId = recordTypeId
        );
        Insert knowObj2;
        
        Knowledge__kav know = [SELECT Id, KnowledgeArticleId FROM Knowledge__kav WHERE Title = 'Article Test 2' LIMIT 1];
        KbManagement.PublishingService.publishArticle(know.KnowledgeArticleId, true);
        
    }

    @IsTest
    static void getRecentlyModifiedArticlesTest(){

        Map<String, Object> mpReturn = UCP_ArticleCarouselRecentlyController.getRecentlyModifiedArticles();
        List<UCP_ArticleCarouselRecentlyController.Knowledge> ltKnowledge = (List<UCP_ArticleCarouselRecentlyController.Knowledge>) mpReturn.get('data');

        Test.startTest();
            System.assertEquals(0, ltKnowledge.size());            
        Test.stopTest();
        
    }
    
    @IsTest
    static void getRecentlyModifiedArticlesPartsTest(){
         Id recordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Knowledge__kav' AND Name = 'UCP Container' LIMIT 1].Id;

        Knowledge__kav knowObj = new Knowledge__kav(
            Title = 'Article Test parts',
            UrlName = 'article-test-parts',
            NATT_Parts_Bulletin__c = true,
            recordTypeId = recordTypeId
        );
        Insert knowObj;
        
        Knowledge__kav know = [SELECT Id, KnowledgeArticleId FROM Knowledge__kav WHERE Title = 'Article Test parts' LIMIT 1];
        KbManagement.PublishingService.publishArticle(know.KnowledgeArticleId, true);        

        Map<String, Object> mpReturn = UCP_ArticleCarouselRecentlyController.getRecentlyModifiedArticles();
        List<UCP_ArticleCarouselRecentlyController.Knowledge> ltKnowledge = (List<UCP_ArticleCarouselRecentlyController.Knowledge>) mpReturn.get('data');

        Test.startTest();
            System.assertEquals('Article Test parts', ltKnowledge[0].title);
            System.assertEquals('NATT_parts_bulletin', ltKnowledge[0].iconType);
        Test.stopTest();
        
    }
    
    @IsTest
    static void getRecentlyModifiedArticlesServiceTest(){
         Id recordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Knowledge__kav' AND Name = 'UCP Container' LIMIT 1].Id;
        
        Knowledge__kav knowObj = new Knowledge__kav(
            Title = 'Article Test service',
            UrlName = 'article-test-service',
            recordTypeId = recordTypeId,
            NATT_Service_Bulletin__c = true
        );
        Insert knowObj;
        
        Knowledge__kav know = [SELECT Id, KnowledgeArticleId FROM Knowledge__kav WHERE Title = 'Article Test service' LIMIT 1];
        KbManagement.PublishingService.publishArticle(know.KnowledgeArticleId, true);   

        Map<String, Object> mpReturn = UCP_ArticleCarouselRecentlyController.getRecentlyModifiedArticles();
        List<UCP_ArticleCarouselRecentlyController.Knowledge> ltKnowledge = (List<UCP_ArticleCarouselRecentlyController.Knowledge>) mpReturn.get('data');

        Test.startTest();
            System.assertEquals('Article Test service', ltKnowledge[0].title);
            System.assertEquals('NATT_service_bulletin', ltKnowledge[0].iconType);
        Test.stopTest();
        
    }
    
    @IsTest
    static void getRecentlyModifiedArticlesTrainingTest(){
        Id recordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Knowledge__kav' AND Name = 'UCP Container' LIMIT 1].Id;
        Knowledge__kav knowObj = new Knowledge__kav(
            Title = 'Article Test training',
            UrlName = 'article-test-training',
            recordTypeId = recordTypeId,
            NATT_Training_Bulletin__c = true
        );
        Insert knowObj;
        
        Knowledge__kav know = [SELECT Id, KnowledgeArticleId FROM Knowledge__kav WHERE Title = 'Article Test training' LIMIT 1];
        KbManagement.PublishingService.publishArticle(know.KnowledgeArticleId, true);   

        Map<String, Object> mpReturn = UCP_ArticleCarouselRecentlyController.getRecentlyModifiedArticles();
        List<UCP_ArticleCarouselRecentlyController.Knowledge> ltKnowledge = (List<UCP_ArticleCarouselRecentlyController.Knowledge>) mpReturn.get('data');

        Test.startTest();
            System.assertEquals('Article Test training', ltKnowledge[0].title);
            System.assertEquals('NATT_training_bulletin', ltKnowledge[0].iconType);
        Test.stopTest();
        
    }
    
    @IsTest
    static void getRecentlyModifiedArticlesProductTest(){
       	Id recordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Knowledge__kav' AND Name = 'UCP Container' LIMIT 1].Id;

        Knowledge__kav knowObj = new Knowledge__kav(
            Title = 'Article Test product',
            UrlName = 'article-test-product',
             recordTypeId = recordTypeId,
            NATT_Product_Manual_Updates__c = true
        );
        Insert knowObj;
        
        Knowledge__kav know = [SELECT Id, KnowledgeArticleId FROM Knowledge__kav WHERE Title = 'Article Test product' LIMIT 1];
        KbManagement.PublishingService.publishArticle(know.KnowledgeArticleId, true);   

        Map<String, Object> mpReturn = UCP_ArticleCarouselRecentlyController.getRecentlyModifiedArticles();
        List<UCP_ArticleCarouselRecentlyController.Knowledge> ltKnowledge = (List<UCP_ArticleCarouselRecentlyController.Knowledge>) mpReturn.get('data');

        Test.startTest();
            System.assertEquals('Article Test product', ltKnowledge[0].title);
            System.assertEquals('NATT_product_manual_updates', ltKnowledge[0].iconType);
        Test.stopTest();
        
    }
    
   /* @IsTest
    static void getRecentlyModifiedArticlesDealerNewsTest(){
        
        Knowledge__kav knowObj = new Knowledge__kav(
            Title = 'Article Test dealer news',
            UrlName = 'article-test-dealer-news',
            NATT_Dealer_News__c = true
        );
        Insert knowObj;
        
        Knowledge__kav know = [SELECT Id, KnowledgeArticleId FROM Knowledge__kav WHERE Title = 'Article Test dealer news' LIMIT 1];
        KbManagement.PublishingService.publishArticle(know.KnowledgeArticleId, true);   

        Map<String, Object> mpReturn = UCP_ArticleCarouselRecentlyController.getRecentlyModifiedArticles();
        List<UCP_ArticleCarouselRecentlyController.Knowledge> ltKnowledge = (List<UCP_ArticleCarouselRecentlyController.Knowledge>) mpReturn.get('data');

        Test.startTest();
            System.assertEquals('Article Test dealer news', ltKnowledge[0].title);
            System.assertEquals('NATT_dealer_news', ltKnowledge[0].iconType);
        Test.stopTest();
        
    }*/
    
    @IsTest
  	static void getRecentlyModifiedArticlesFlashTest(){
        Id recordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Knowledge__kav' AND Name = 'UCP Container' LIMIT 1].Id;
        
        Knowledge__kav knowObj = new Knowledge__kav(
            Title = 'Article Test eFlash',
            UrlName = 'article-test-eFlash',
            recordTypeId = recordTypeId,
            NATT_eFlash__c = true
        );
        Insert knowObj;
        
        Knowledge__kav know = [SELECT Id, KnowledgeArticleId FROM Knowledge__kav WHERE Title = 'Article Test eFlash' LIMIT 1];
        KbManagement.PublishingService.publishArticle(know.KnowledgeArticleId, true);   

        Map<String, Object> mpReturn = UCP_ArticleCarouselRecentlyController.getRecentlyModifiedArticles();
        List<UCP_ArticleCarouselRecentlyController.Knowledge> ltKnowledge = (List<UCP_ArticleCarouselRecentlyController.Knowledge>) mpReturn.get('data');

        Test.startTest();
            System.assertEquals('Article Test eFlash', ltKnowledge[0].title);
            System.assertEquals('NATT_eflash', ltKnowledge[0].iconType);
        Test.stopTest();
        
    }
    
    @IsTest
    static void getRecentlyModifiedArticlesFailTest(){
        NATT_Utils.isError = true;
        Map<String, Object> mpReturn = UCP_ArticleCarouselRecentlyController.getRecentlyModifiedArticles();
        
        Test.startTest();
            System.assertEquals(false, (Boolean) mpReturn.get('success') );
        Test.stopTest();
        
    }

}