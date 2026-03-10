public with sharing class EmailService {
    /**
     * Sends an email notification with details of modified field values.
     * @param diffMap Map of record Id to difference string (showing old value → new value)
     * @param updatedByUser Name of the user who last modified the record(s)
     */
    public static void sendApprovalProcessEmail(Map<Id, String> diffMap, String updatedByUser) {
        // Build the email body with the updated format including the last modified user
        String emailBody = 'Hi Team,\n\n' +
                           'Following record(s) on the NATT Approval Process have been updated by ' + updatedByUser + '. ' +
                           'These are the updated values:\n\n';
        
        // Loop through each record's differences and add them to the body
        for (Id recId : diffMap.keySet()) {
            emailBody += 'Record Id: ' + recId + '\n';
            emailBody += diffMap.get(recId);
            emailBody += '--------------------------\n';
        }
        
        emailBody += '\nBest Regards';
        
        // Retrieve recipients from the custom label and split by semicolon
        String recipientsStr = System.Label.Approval_Process_Recipients;
        List<String> recipientList = recipientsStr.split(';');
        // Trim any extra spaces from each email address
        for (Integer i = 0; i < recipientList.size(); i++) {
            recipientList[i] = recipientList[i].trim();
        }
        
        // Create and configure the email message
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(recipientList);
        mail.setSubject('NATT Approval Process Record Updated');
        mail.setPlainTextBody(emailBody);
        
        // Send the email and capture the results
        Messaging.SendEmailResult[] results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        if (results != null && results.size() > 0) {
            for (Messaging.SendEmailResult res : results) {
                if (!res.isSuccess()) {
                    for (Messaging.SendEmailError err : res.getErrors()) {
                        System.debug('Email send error: ' + err.getMessage());
                    }
                }
            }
        }
        System.debug('Email has been sent for updated records.');
    }
}