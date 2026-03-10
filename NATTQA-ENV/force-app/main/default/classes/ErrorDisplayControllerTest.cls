@isTest
public class ErrorDisplayControllerTest {
    @isTest
    public static void doRedirectTest(){
        
        Opportunity Opp = new Opportunity();
        Opp.Name = 'Test Opportiunity ';
        Opp.CloseDate = System.today();
        Opp.StageName = 'Qualified';
        insert Opp;
        
        ApexPages.StandardController sc = new ApexPages.StandardController(Opp);
        
        Test.startTest(); 
        ErrorDisplayController newCtrlr = new ErrorDisplayController(sc);
        newCtrlr.objName = 'Opportunity';
        newCtrlr.doRedirect();
        newCtrlr.objName = 'SBQQ__Quote__c';
        newCtrlr.doRedirect();
        newCtrlr.objName = 'Order';
        newCtrlr.doRedirect();
        Test.stopTest();
    }
}