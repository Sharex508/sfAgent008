trigger NATTApprovalProcessTrigger on NATT_Approval_Process__c (after update) {
    // Map to hold differences: key = record Id, value = difference string
    Map<Id, String> diffMap = new Map<Id, String>();
    
    // Loop through updated records and compare with their old values
   for (NATT_Approval_Process__c newRec : Trigger.new) {
        NATT_Approval_Process__c oldRec = Trigger.oldMap.get(newRec.Id);
        String diffStr = '';
        
        if (newRec.Name != oldRec.Name) {
            diffStr += 'Name: ' + oldRec.Name + ' -> ' + newRec.Name + '\n';
        }
        if (newRec.Product_Name__c != oldRec.Product_Name__c) {
            diffStr += 'Product Name: ' + oldRec.Product_Name__c + ' -> ' + newRec.Product_Name__c + '\n';
        }
        if (newRec.Approval_Object__c != oldRec.Approval_Object__c) {
            diffStr += 'Approval Object: ' + oldRec.Approval_Object__c + ' -> ' + newRec.Approval_Object__c + '\n';
        }
        if (newRec.Business_Type__c != oldRec.Business_Type__c) {
            diffStr += 'Business Type: ' + oldRec.Business_Type__c + ' -> ' + newRec.Business_Type__c + '\n';
        }
        if (newRec.Business_Sub_Type__c != oldRec.Business_Sub_Type__c) {
            diffStr += 'Business Sub Type: ' + oldRec.Business_Sub_Type__c + ' -> ' + newRec.Business_Sub_Type__c + '\n';
        }
        if (newRec.Margin_EAM_Lower_Bound__c != oldRec.Margin_EAM_Lower_Bound__c) {
            diffStr += 'Margin % EAM Lower Bound: ' + oldRec.Margin_EAM_Lower_Bound__c + ' -> ' + newRec.Margin_EAM_Lower_Bound__c + '\n';
        }
        if (newRec.Margin_RD_Lower_Bound__c != oldRec.Margin_RD_Lower_Bound__c) {
            diffStr += 'Margin % RD Lower Bound: ' + oldRec.Margin_RD_Lower_Bound__c + ' -> ' + newRec.Margin_RD_Lower_Bound__c + '\n';
        }
        if (newRec.Margin_DOS_Lower_Bound__c != oldRec.Margin_DOS_Lower_Bound__c) {
            diffStr += 'Margin % DOS Lower Bound: ' + oldRec.Margin_DOS_Lower_Bound__c + ' -> ' + newRec.Margin_DOS_Lower_Bound__c + '\n';
        }
        if (newRec.Margin_Sales_Ops_Lower_Bound__c != oldRec.Margin_Sales_Ops_Lower_Bound__c) {
            diffStr += 'Margin % Sales Ops Lower Bound: ' + oldRec.Margin_Sales_Ops_Lower_Bound__c + ' -> ' + newRec.Margin_Sales_Ops_Lower_Bound__c + '\n';
        }
        /*if (newRec.Margin_VP_or_CFO_Lower_Bound__c != oldRec.Margin_VP_or_CFO_Lower_Bound__c) {
            diffStr += 'Margin % VP or CFO Lower Bound: ' + oldRec.Margin_VP_or_CFO_Lower_Bound__c + ' -> ' + newRec.Margin_VP_or_CFO_Lower_Bound__c + '\n';
        }
        if (newRec.Margin_EAM_Upper_Bound__c != oldRec.Margin_EAM_Upper_Bound__c) {
            diffStr += 'Margin % EAM Upper Bound: ' + oldRec.Margin_EAM_Upper_Bound__c + ' -> ' + newRec.Margin_EAM_Upper_Bound__c + '\n';
        }
        if (newRec.Margin_RD_Upper_Bound__c != oldRec.Margin_RD_Upper_Bound__c) {
            diffStr += 'Margin % RD Upper Bound: ' + oldRec.Margin_RD_Upper_Bound__c + ' -> ' + newRec.Margin_RD_Upper_Bound__c + '\n';
        }
        if (newRec.Margin_DOS_Upper_Bound__c != oldRec.Margin_DOS_Upper_Bound__c) {
            diffStr += 'Margin % DOS Upper Bound: ' + oldRec.Margin_DOS_Upper_Bound__c + ' -> ' + newRec.Margin_DOS_Upper_Bound__c + '\n';
        }
        if (newRec.Margin_Sales_Ops_Upper_Bound__c != oldRec.Margin_Sales_Ops_Upper_Bound__c) {
            diffStr += 'Margin % Sales Ops Upper Bound: ' + oldRec.Margin_Sales_Ops_Upper_Bound__c + ' -> ' + newRec.Margin_Sales_Ops_Upper_Bound__c + '\n';
        }
        if (newRec.Margin_VP_of_CFO_Upper_Bound__c != oldRec.Margin_VP_of_CFO_Upper_Bound__c) {
            diffStr += 'Margin % VP of CFO Upper Bound: ' + oldRec.Margin_VP_of_CFO_Upper_Bound__c + ' -> ' + newRec.Margin_VP_of_CFO_Upper_Bound__c + '\n';
        }*/
        
        if (diffStr != '') {
            diffMap.put(newRec.Id, diffStr);
        }
    }
    
    // If there are any differences, retrieve the LastModifiedBy name from the first record
    if (!diffMap.isEmpty()) {
        String updatedByUser = Trigger.new[0].LastModifiedBy.Name;
        Trigger_Control__mdt triggerControl = [ SELECT id,Is_Trigger_Enabled__c FROM Trigger_Control__mdt WHERE DeveloperName = 'EmailService' LIMIT 1];
        if (triggerControl != null && triggerControl.Is_Trigger_Enabled__c ){   
            EmailService.sendApprovalProcessEmail(diffMap, updatedByUser);
        }
        System.debug('Email has been sent for updated records with differences: ' + diffMap);
    }
}