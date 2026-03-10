/*************************************************************************************************
Apex Class Name : CoreReturnsCaseCloseEmailAlertBatch
Version : 1.0
Created Date : 06/06/2023
Function : To auto close the Core Returns cases which do not have any return Items added for 14 days after the case is created and to send email notification to “Contact Name” & “Created By” on the Case

Modification Log:
-------------------------------------------------------------------------------------------------------------------------------------------------
* Developer                                Date                                Description
* -----------------------------------------------------------------------------------------------------------------------------------------------
* Sanjay Sarraf         		     06/06/2023                        Initial creation        
*************************************************************************************************/

public class CoreReturnsCaseCloseEmailAlertBatch implements Database.Batchable<SObject>, Database.Stateful {
	
    //Batch Start method
    public Database.QueryLocator start(Database.BatchableContext BC) {
		String query = 'Select id,Status,CreatedBy.email,ContactEmail,CaseNumber,NATT_Number_of_Return_Line_Items__c,RecordType.Name from Case WHERE Status = \'NEW\' AND NATT_Number_of_Return_Line_Items__c = 0 AND RecordType.Name=\'Core Returns\' AND CreatedDate = N_DAYS_AGO:15';
        return Database.getQueryLocator(query);
    }

    //Batch Execute method 
    public void execute(Database.BatchableContext BC, List<sObject> scopeList) {
        System.debug(LoggingLevel.INFO, '== scopeList size ==' + scopeList.size());
        
        List<Case> caseList = (List<Case>) scopeList;
        if(!caseList.isEmpty()) {
			List<Case> updCaseList = new List<Case>();
            List<Messaging.SingleEmailMessage> mailList = new List<Messaging.SingleEmailMessage>();
            for (Case cRcd : caseList){               
                cRcd.Status='Closed';
				cRcd.NATT_Close_Reason__c = Label.caseReason;
				cRcd.NATT_Close_Reason_Explanation__c = Label.caseReasonExplanation;
				updCaseList.add(cRcd);
                Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage(); 
                List<String> toAddresses = new List<String>();
				if(cRcd.ContactEmail!=''){
					toAddresses.add(cRcd.ContactEmail);
				}
				if(cRcd.CreatedBy.email!=''){
					toAddresses.add(cRcd.CreatedBy.email);
				}
				
				message.setSubject('Case Close Notification - Case Number: '+cRcd.CaseNumber);
                message.setToAddresses(toAddresses);
				String bodyText='Case Number: ' + cRcd.CaseNumber + '<br/>';
				bodyText += 'Close Reason: ' + 'Other' + '<br/>';
				bodyText += 'Close Reason Explanation: ' + 'Missing case line item detail. PPG cannot take further action.' + '<br/>';
				bodyText += '<a href="'+URL.getSalesforceBaseUrl().toExternalForm()+'/'+cRcd.id+'"> Link to the Case </a>' ; 
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