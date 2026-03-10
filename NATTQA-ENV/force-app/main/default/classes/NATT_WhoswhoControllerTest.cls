@IsTest
public with sharing class NATT_WhoswhoControllerTest {

    @TestSetup
    static void makeData() {
        
        Knowledge__kav knowObj1 = new Knowledge__kav(
            Title = 'Article Test 1',
            UrlName = 'article-test-1',
            NATT_Whos_who__c = false
        );
        Insert knowObj1;
        
        Knowledge__kav knowObj2 = new Knowledge__kav(
            Title = 'Who is who article',
            UrlName = 'who-is-who',
            NATT_Whos_who__c = true
        );
        Insert knowObj2;
        
        Knowledge__kav know = [SELECT Id, KnowledgeArticleId FROM Knowledge__kav WHERE Title = 'Who is who article' LIMIT 1];
        KbManagement.PublishingService.publishArticle(know.KnowledgeArticleId, true);

        Knowledge__kav know2 = [SELECT Id, KnowledgeArticleId FROM Knowledge__kav WHERE Title = 'Article Test 1' LIMIT 1];
        KbManagement.PublishingService.publishArticle(know2.KnowledgeArticleId, true);
        
    }

    @IsTest
    static void getWhosWhoArticleTest(){

        Map<String, Object> mpReturn = NATT_WhoswhoController.getWhosWhoArticle();
        List<Knowledge__kav> ltKnowledge = (List<Knowledge__kav>) mpReturn.get('data');
        
        Test.startTest();
            System.assertEquals(1, ltKnowledge.size());
            System.assertEquals('Who is who article', ltKnowledge[0].title);
        Test.stopTest();
        
    }

    @IsTest
    static void getWhosWhoArticleFailTest(){

        NATT_Utils.isError = true;
        Map<String, Object> mpReturn = NATT_WhoswhoController.getWhosWhoArticle();
        
        Test.startTest();
            System.assertEquals(false, (Boolean) mpReturn.get('success') );
        Test.stopTest();
        
    }

}