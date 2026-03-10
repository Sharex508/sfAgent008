/********************************************************************************************************
* @author         (Deloitte)
* @description    This is a test class for KnowledgeSearch_UCPController apex class created specific for REF Dealer users.
* @date           03/29/2023 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Deloitte               03/29/2023                                  Initial version
*********************************************************************************************************/
@isTest
public class KnowledgeSearch_UCPController_Test {
    
    @isTest
    static void getPickList_Test() {
        KnowledgeSearch_UCPController.WrapPicklist wrapknowledgePicklist = new KnowledgeSearch_UCPController.WrapPicklist();
        
        Test.startTest();
        wrapknowledgePicklist = KnowledgeSearch_UCPController.getPickList();
        Test.stopTest();
        
       // boolean tstResult = wrapknowledgePicklist.department[0] != null;
       // system.assertEquals(tstResult, true);
    }
    
    @isTest
    static void getArticleList_Test() {
        list<Knowledge__kav> knowSearchResult = new list<Knowledge__kav>();
        
        Test.startTest();
        knowSearchResult = KnowledgeSearch_UCPController.getArticleList('Test', 'tst', '000123','Warranty', 'Forms');
        Test.stopTest();
        
        boolean tstResult = knowSearchResult.size() == 0;
        system.assertEquals(tstResult, true);
    }
    
}