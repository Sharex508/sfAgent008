@isTest
public class NAC_ReturnItemsPDFTest {
 @isTest(SeeAllData=true)
     static void createReturnPDF(){
          Case c1=[SELECT Id,CaseNumber,NATT_Core_Return_Location_Account__r.Name, (SELECT Name, NATT_Part_Number__c, NATT_Quantity__c, NATT_Serial__c, NATT_Warranty__c, NATT_MPR_Tag__c, NATT_Received_Core__c, NATT_Accepted_Quantity__c, NATT_Rejected_Quantity__c, NATT_Remarks_Notes__c   FROM Return_Items__r) FROM Case LIMIT 1];
          Test.startTest();
          ApexPages.StandardController sc = new ApexPages.StandardController(c1); 
          NAC_ReturnItemsPDF nPDF=new NAC_ReturnItemsPDF(sc);
          Test.stopTest();
          system.assertNotEquals(nPDF, null, 'not able to fetch any data , check your conditions');
     }
}