@isTest
public class NAC_coreCaseDetailTest {
    
  @isTest(SeeAllData=true)
    static void createTest(){
        Case c1=[SELECT Id,CaseNumber,NATT_Core_Return_Location_Account__r.Name, (SELECT Name, NATT_Part_Number__c, NATT_Quantity__c, NATT_Serial__c, NATT_Warranty__c, NATT_MPR_Tag__c, NATT_Received_Core__c, NATT_Accepted_Quantity__c, NATT_Rejected_Quantity__c, NATT_Remarks_Notes__c   FROM Return_Items__r) FROM Case LIMIT 1];
        String caseNum=c1.CaseNumber;
        
        Test.startTest();
        NAC_coreCaseDetail nc=new NAC_coreCaseDetail();
        nc.caseNum=caseNum;
        List<Case> cs=nc.getcaseDetails();
        Test.stopTest();
        system.assertNotEquals(cs.size(), null, 'There is no case available with the case number');
    }
}