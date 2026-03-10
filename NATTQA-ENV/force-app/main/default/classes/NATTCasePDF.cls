public class NATTCasePDF
{
    public Case c {get;set;}
    public NATTCasePDF(ApexPages.StandardController con)
    {
        c = [SELECT Id,CaseNumber, (SELECT Name, NATT_Part_Number__c, NATT_Quantity__c, NATT_Serial__c, NATT_Warranty__c, NATT_MPR_Tag__c, NATT_Received_Core__c, NATT_Accepted_Quantity__c, NATT_Rejected_Quantity__c, NATT_Remarks_Notes__c   FROM Return_Items__r) FROM Case WHERE Id=:con.getId()];               
    }   
}