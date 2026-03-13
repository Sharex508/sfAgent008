// Quote submit/approve helper from manual video analysis.
// Run with:
// sf apex run --target-org <ORG_ALIAS> --file scripts/video_repro/quote_submit_and_approve.apex

String captureId = '__CAPTURE_ID__';
if (captureId == '__CAPTURE_ID__') {
    captureId = 'VIDEO_REPRO_APPROVAL_' + Datetime.now().formatGMT('yyyyMMdd_HHmmss');
}
System.debug('PROCESS_CAPTURE_ID=' + captureId);

// Injected by run_direct_sales_capture.ps1 or manually updated before execution.
String TARGET_QUOTE_NUMBER = '__TARGET_QUOTE_NUMBER__';
if (TARGET_QUOTE_NUMBER == '__TARGET_QUOTE_NUMBER__') {
    TARGET_QUOTE_NUMBER = 'Q-25088';
}

Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
if (!gd.containsKey('SBQQ__Quote__c')) {
    System.debug('SBQQ__Quote__c object not found. Skipping quote approval helper.');
} else {
    List<SBQQ__Quote__c> candidates;
    if (TARGET_QUOTE_NUMBER != null && TARGET_QUOTE_NUMBER.trim() != '') {
        candidates = [
            SELECT Id, Name, SBQQ__Status__c
            FROM SBQQ__Quote__c
            WHERE Name = :TARGET_QUOTE_NUMBER
            LIMIT 1
        ];
    } else {
        candidates = [
            SELECT Id, Name, SBQQ__Status__c
            FROM SBQQ__Quote__c
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
    }

    if (candidates.isEmpty()) {
        System.debug('No quote found for approval helper execution.');
    } else {
        SBQQ__Quote__c quote = candidates[0];
        System.debug('QUOTE_SELECTED=' + quote.Name + ' (' + quote.Id + ')');

        // 1) Submit for approval
        Approval.ProcessSubmitRequest submitReq = new Approval.ProcessSubmitRequest();
        submitReq.setObjectId(quote.Id);
        submitReq.setComments('Please Approve - ' + captureId);
        Approval.ProcessResult submitRes = Approval.process(submitReq);
        System.debug('SUBMIT_SUCCESS=' + submitRes.isSuccess());

        // 2) Attempt approval for pending workitems assigned to current user
        List<ProcessInstanceWorkitem> workItems = [
            SELECT Id, ActorId, ProcessInstance.TargetObjectId
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId = :quote.Id
        ];

        for (ProcessInstanceWorkitem wi : workItems) {
            Approval.ProcessWorkitemRequest approveReq = new Approval.ProcessWorkitemRequest();
            approveReq.setWorkitemId(wi.Id);
            approveReq.setAction('Approve');
            approveReq.setComments('Approved via script - ' + captureId);
            Approval.ProcessResult approveRes = Approval.process(approveReq);
            System.debug('APPROVE_WORKITEM=' + wi.Id + ' SUCCESS=' + approveRes.isSuccess());
        }

        System.debug('QUOTE_ID=' + quote.Id);
    }
}
System.debug('PROCESS_CAPTURE_ID=' + captureId);
