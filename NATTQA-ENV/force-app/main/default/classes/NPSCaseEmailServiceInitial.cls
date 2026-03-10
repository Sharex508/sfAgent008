/**
 * @description Invocable wrapper to trigger initial NPS Case notification emails
 *              via Flow/Process, delegating to NPSCaseEmailService.
 */
public class NPSCaseEmailServiceInitial {
    // This is the invocable method used by Flows or other classes
    @InvocableMethod(label='Send NPS initial Email' description='Sends case creation email for the given case(s)')
    /**
     * @method sendEmailToManagers
     * @description Invocable entry point that iterates provided Case Ids and
     *              calls NPSCaseEmailService.sendNPSApprovalEmail with type 'Initial'.
     * @param caseIds List of Case record Ids to notify.
     * @details Designed for Flow/Process Builder usage. For each Case Id,
     *          delegates email composition/sending to NPSCaseEmailService.
     * @return void
     * @see NPSCaseEmailService.sendNPSApprovalEmail
     */
    public static void sendEmailToManagers(List<Id> caseIds) {
        String type = 'Initial';
        for (Id caseId : caseIds) {
            NPSCaseEmailService.sendNPSApprovalEmail(caseId, type);
        }
    }

}