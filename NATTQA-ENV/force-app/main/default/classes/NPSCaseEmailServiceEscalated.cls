/**
 * @description Invocable wrapper to trigger NPS Case escalation emails
 *              via Flow/Process, delegating to NPSCaseEmailService.
 */
public class NPSCaseEmailServiceEscalated {
    @InvocableMethod(label='Send NPS Approval Email1' description='Sends approval email for the given case(s)')
    /**
     * @method sendEmailToManagers1
     * @description Invocable entry point that iterates provided Case Ids and
     *              calls NPSCaseEmailService.sendNPSApprovalEmail with type 'escalated'.
     * @param caseIds List of Case record Ids to notify/escalate.
     * @details Designed for Flow/Process Builder usage. For each Case Id,
     *          delegates email composition/sending and potential owner/status update
     *          to NPSCaseEmailService.
     * @return void
     * @see NPSCaseEmailService.sendNPSApprovalEmail
     */
    public static void sendEmailToManagers1(List<Id> caseIds) {
        string Type  = 'escalated';
        for (Id caseId : caseIds) {
            
            NPSCaseEmailService.sendNPSApprovalEmail(caseId, Type);  // Call your existing email logic for each Case Id
        }
    }

}