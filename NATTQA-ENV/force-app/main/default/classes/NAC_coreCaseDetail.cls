public class NAC_coreCaseDetail {
    
   public List<Case> c{get;set;}
   public String caseNum{get;set;}

	public nac_coreCaseDetail() {
    }

	public List<Case> getcaseDetails() {
        if(caseNum != null){ //To show at the time of preview of the vf email template
           c = [SELECT Id,CaseNumber,NATT_Core_Return_Location_Account__r.Name, (SELECT Name, NATT_Part_Number__c, NATT_Quantity__c, NATT_Serial__c, NATT_Warranty__c, NATT_MPR_Tag__c, NATT_Received_Core__c, NATT_Accepted_Quantity__c, NATT_Rejected_Quantity__c, NATT_Remarks_Notes__c   FROM Return_Items__r) FROM Case  WHERE CaseNumber=:caseNum];
        }
		return c;
	}
}