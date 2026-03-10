/**
 * @description Handles NPS Case email notifications (Initial, Overdue, Escalated)
 *              and updates Case ownership based on escalation level.
 */
public class NPSCaseEmailService {

    // The main method to send emails
    /**
     * @description Sends NPS Case notification email and manages escalation.
     *              Resolves approvers via Custom Metadata and Account Team.
     * @param caseId The Case Id to process for notification and potential escalation.
     * @param type The notification type. Allowed values: 'Initial', 'Overdue', 'Escalated'.
     * @details
     *   - Queries Case with related Account/Contact and NPS feedback fields.
     *   - Looks up approver roles from NPS_approval_mapping__mdt for L0/L1/L2.
     *   - Finds matching Account Team Members for those roles to address/assign.
     *   - Composes and sends an HTML and plain-text email to the resolved recipient.
     *   - For 'Overdue' and 'Escalated', updates Case Status and reassigns Owner.
     * @return void
     * @throws DmlException If Case update fails during owner/status change.
     * @throws EmailException If email sending fails.
     * @usage NPSCaseEmailService.sendNPSApprovalEmail(someCaseId, 'Initial');
     * @see NPS_approval_mapping__mdt
     */
    public static void sendNPSApprovalEmail(Id caseId, String type) {
        System.debug('Fetching Case with Id: ' + caseId);
        
        // Query to include nps_Response_Main_score__c from the response object
        Case caseRecord = [ 
            SELECT Id,NPS_Account__c,NPS_Account__r.Name,NPS_Contact__r.Email,NPS_Contact__r.Phone,NPS_Contact__r.Name, AccountId, Contact.Email, Contact.Phone, Contact.Name, Account.Name,
                nps_NPS_Feedback_id__r.NPS_Likelihood_to_recommend__c, Customer_Survey_Type__c, 
                nps_NPS_Feedback_id__r.nps_Response_Main_score__c,RecordTypeId, RecordType.DeveloperName,NPS_Account__r.NATT_Dealership__c,NPS_Account__r.RecordType.DeveloperName,
                Owner.Email, Owner.Name,status
            FROM Case WHERE Id = :caseId LIMIT 1
        ];
        
        system.debug('Case Details ' + caseRecord);
        
        // Retrieve role mappings based on Customer_Survey_Type__c
        List<NPS_approval_mapping__mdt> roleMappings = [
            SELECT Business_Type__c, Role__c, Approver_level__c FROM NPS_approval_mapping__mdt 
            WHERE Business_Type__c = :caseRecord.Customer_Survey_Type__c
            AND Approver_level__c IN ('L0', 'L1', 'L2')
        ];
        system.debug('get approval mapping ' + roleMappings);
        
        Map<String, String> approverLevelToRoleMap = new Map<String, String>();
        for (NPS_approval_mapping__mdt mapping : roleMappings) {
            approverLevelToRoleMap.put(mapping.Approver_level__c, mapping.Role__c);
        }
        system.debug('get approval mapping map ' + approverLevelToRoleMap);

        // Fetch Account Team Members with User Id
       Id accountIdFilter;
       // Pick the AccountId filter dynamically based on RecordType
        if (caseRecord.NPS_Account__r.RecordType.DeveloperName == 'Dealer') {
            accountIdFilter = caseRecord.NPS_Account__c;
        } else if (caseRecord.NPS_Account__r.RecordType.DeveloperName == 'Customer') {
            accountIdFilter = caseRecord.NPS_Account__r.NATT_Dealership__c; 
        }
       List<AccountTeamMember> teamMembers = [
            SELECT User.Id, User.Email, User.Name, TeamMemberRole FROM AccountTeamMember 
            WHERE AccountId = :accountIdFilter
            AND TeamMemberRole IN :approverLevelToRoleMap.values()
        ];
        system.debug('Accounts team member ' + teamMembers);
        
        Map<String, String> roleToEmailMap = new Map<String, String>();
        Map<String, String> roleToNameMap = new Map<String, String>();
        Map<String, Id> roleToUserIdMap = new Map<String, Id>();
        for (AccountTeamMember teamMember : teamMembers) {
            roleToEmailMap.put(teamMember.TeamMemberRole, teamMember.User.Email);
            roleToNameMap.put(teamMember.TeamMemberRole, teamMember.User.Name);
            roleToUserIdMap.put(teamMember.TeamMemberRole, teamMember.User.Id);
        }
        system.debug('Accounts team member map  ' + roleToEmailMap);

        // Retrieve emails and names
        String l0ManagerEmail = roleToEmailMap.get(approverLevelToRoleMap.get('L0'));
        String l1ManagerEmail = roleToEmailMap.get(approverLevelToRoleMap.get('L1'));
        String l2ManagerEmail = roleToEmailMap.get(approverLevelToRoleMap.get('L2'));
        
        // Retrieve manager names
        String l0ManagerName = roleToNameMap.get(approverLevelToRoleMap.get('L0'));
        String l1ManagerName = roleToNameMap.get(approverLevelToRoleMap.get('L1'));
        
        System.debug('L0 Manager Email: ' + l0ManagerEmail);
        System.debug('L1 Manager Email: ' + l1ManagerEmail);
        System.debug('L2 Manager Email: ' + l2ManagerEmail);
        System.debug('L0 Manager Name: ' + l0ManagerName);
        System.debug('L1 Manager Name: ' + l1ManagerName);
        
        // Prepare email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        List<String> ccAddresses = new List<String>();
        String toEmail = null;
        Id newOwnerId = null;

        // Set the recipient addresses based on the type
        if (type == 'Initial') {
            toEmail = caseRecord.Owner.Email;
        } else if (type == 'Overdue') {
            caseRecord.Status='Overdue';
            toEmail = l1ManagerEmail;
            newOwnerId = roleToUserIdMap.get(approverLevelToRoleMap.get('L1'));
            System.debug('To Email (Overdue): ' + toEmail);
        } else if (type == 'Escalated') {
            caseRecord.Status='Escalated';
            toEmail = l2ManagerEmail;
            newOwnerId = roleToUserIdMap.get(approverLevelToRoleMap.get('L2'));
            System.debug('To Email (Escalated): ' + toEmail);
        }

        // Only proceed if there is a valid "To" email address
        if (toEmail != null) {
            System.debug('To Email toEmail ' + toEmail);
            email.setToAddresses(new String[] { toEmail });
            if (!ccAddresses.isEmpty()) email.setCcAddresses(ccAddresses);

            // Set email subject based on the type using if-else
            String subject = '';
            if (type == 'Initial') {
                subject = 'Customer Feedback followup : New Case';
            } else if (type == 'Overdue' || type == 'Escalated') {
                subject = 'Detractor NPS Response – Action Needed Within 2 or 14 Days';
            } 
            email.setSubject(subject);
            System.debug('Email Subject: ' + subject);

            // Define the HTML body based on the type
            String bodyMessage;
            if (type == 'Initial') {
                bodyMessage = '<p>A customer has recently provided unsatisfactory feedback. Please contact &quot;' + caseRecord.NPS_Contact__r.Name + '&quot; and log the outcome as soon as possible.</p>';
            } else if (type == 'Overdue' || type=='Escalated') {
                bodyMessage = '<p>A NPS survey was recently completed by a Detractor.  A case has been created for the follow-up and it has either been escalated to you or open for 2/14 days.</p>';
            } 

            String caseUrl = System.Url.getOrgDomainUrl().toExternalForm() + '/lightning/r/Case/' + caseRecord.Id + '/view';

            String htmlBody = '<html><body style="font-family: Arial, sans-serif; line-height: 1;">';
            htmlBody += '<div style="text-align:center;">';
            htmlBody += '</div><div style="margin-top: 20px;">' + bodyMessage;
            htmlBody += '<p><strong>Account:</strong> ' + caseRecord.NPS_Account__r.Name + '</p>';
            htmlBody += '<p><strong>Contact:</strong> ' + caseRecord.NPS_Contact__r.Name + '</p>';
            htmlBody += '<p><strong>Email:</strong> ' + caseRecord.NPS_Contact__r.Email + '</p>';
            htmlBody += '<p><strong>Phone Number:</strong> ' + caseRecord.NPS_Contact__r.Phone + '</p>';
            
            // Add the main score from the NPS response
            if (caseRecord.nps_NPS_Feedback_id__r != null && caseRecord.nps_NPS_Feedback_id__r.nps_Response_Main_score__c != null) {
                htmlBody += '<p><strong>Main Score:</strong> ' + caseRecord.nps_NPS_Feedback_id__r.nps_Response_Main_score__c + '</p>';
            }
            
            htmlBody += '<p><strong>Link to Case:</strong> <a href="' + caseUrl + '">' + caseUrl + '</a></p>';
            htmlBody += '</div></body></html>';
            email.setHtmlBody(htmlBody);

            // Plain text version
            email.setPlainTextBody('A customer has recently provided unsatisfactory feedback. Please contact the relevant contact and close the case.');

            // Send the email
            System.debug('Attempting to send email...');
             Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            System.debug('Email sent successfully.');
            Messaging.SendEmailResult emailResult = results.isEmpty() ? null : results[0];
            if(emailResult.getErrors().size()==0 && emailResult.isSuccess()){
                if(type=='Overdue'){
                caseRecord.status='Overdue';
                }

                else if(type=='Escalated'){
                    caseRecord.status='Escalated';
                }
                
            }

            
            // Update Case owner if type is 'Overdue' or 'Escalated'
            if (newOwnerId != null) {
                caseRecord.OwnerId = newOwnerId;
                update caseRecord;
                System.debug('Case owner updated to user with ID: ' + newOwnerId);
            }
        } else {
            System.debug('No valid To email address found for type: ' + type + '. Email not sent.');
        }
    }
}