/*************************************************************************************************
Apex Class Name : ClosedCaseEmailAlertBatch
Version : 1.0
Created Date : 11/05/2023
Function : To auto close the Performance Parts cases which do not have any Line Items added for 14 days after the case is created and to send email notification to “Contact Name” & “Created By” on the Case

Modification Log:
-------------------------------------------------------------------------------------------------------------------------------------------------
* Developer                                Date                                Description
* -----------------------------------------------------------------------------------------------------------------------------------------------
* Sanjay Sarraf         		     11/05/2023                        Initial creation        
*************************************************************************************************/

public class ClosedCaseEmailAlertBatch implements Database.Batchable<SObject>, Database.Stateful {
	
    //Batch Start method
    public Database.QueryLocator start(Database.BatchableContext BC) {
		String query = 'Select id,Status,CreatedBy.email,ContactEmail,CaseNumber,NATT_Number_of_Case_Sales_Order_Records__c,RecordType.Name from Case WHERE Status = \'NEW\' AND NATT_Number_of_Case_Sales_Order_Records__c = 0 AND RecordType.Name=\'Performance Parts\' AND CreatedDate = N_DAYS_AGO:14';
        return Database.getQueryLocator(query);
    }

    //Batch Execute method 
    public void execute(Database.BatchableContext BC, List<sObject> scopeList) {
        System.debug(LoggingLevel.INFO, '== scopeList size ==' + scopeList.size());
        
        List<Case> caseList = (List<Case>) scopeList;
        if(!caseList.isEmpty()) {
			List<Case> updCaseList = new List<Case>();
            List<Messaging.SingleEmailMessage> mailList = new List<Messaging.SingleEmailMessage>();
            for (Case cInst : caseList){               
                cInst.Status='Closed';
				cInst.NATT_Close_Reason__c = Label.caseReason;
				cInst.NATT_Close_Reason_Explanation__c = Label.caseReasonExplanation;
				updCaseList.add(cInst);
                Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage(); 
                List<String> toAddresses = new List<String>();
				if(!String.isBlank(cInst.ContactEmail)){
					toAddresses.add(cInst.ContactEmail);
				}
				if(!String.isBlank(cInst.CreatedBy.email)){
					toAddresses.add(cInst.CreatedBy.email);
				}
				
				message.setSubject('Case Close Notification - Case Number: '+cInst.CaseNumber);
                message.setToAddresses(toAddresses);
				String bodyText='Case Number: ' + cInst.CaseNumber + '<br/>';
				bodyText += 'Close Reason: ' + 'Other' + '<br/>';
				bodyText += 'Close Reason Explanation: ' + 'Missing case line item detail. PPG cannot take further action.' + '<br/>';
				bodyText += '<a href="'+URL.getSalesforceBaseUrl().toExternalForm()+'/'+cInst.id+'"> Link to the Case </a>' ; 
				message.setHTMLBody(bodyText);
                message.SaveAsActivity = false;
                mailList.add(message);
                
            }
            if(!mailList.isEmpty()) {
                try{
					update updCaseList;
                    Messaging.sendEmail(mailList);
                }
                catch (Exception ex) {
                    System.debug('Error is--- '+ex.getMessage());
                }
            }
        }
    }  

    //Batch Finish method for after execution of batch work
    public void finish(Database.BatchableContext BC) { 
        
    }
    
}