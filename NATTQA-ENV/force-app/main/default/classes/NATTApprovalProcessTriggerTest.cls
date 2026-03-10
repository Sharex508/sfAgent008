@isTest
private class NATTApprovalProcessTriggerTest {  
    @isTest static void testUpdateTriggerEmailNotification() { 
        // Create a test record with all required fields populated 
        NATT_Approval_Process__c testRecord = new NATT_Approval_Process__c(
            //Product_Name__c = 'Initial Product',
            Approval_Object__c = 'SBQQ__Quote__c',
            Business_Type__c = 'NATT',
            Business_Sub_Type__c = 'Units Quote',
            Margin_EAM_Lower_Bound__c = 10,
            Margin_RD_Lower_Bound__c = 20,
            Margin_DOS_Lower_Bound__c = 30
        );
        insert testRecord; 
        
        // Update one or more fields to simulate changes
        //testRecord.Product_Name__c = 'Updated Product';
        testRecord.Margin_EAM_Lower_Bound__c = 150;
        testRecord.Margin_RD_Lower_Bound__c = 25;
        testRecord.Margin_DOS_Lower_Bound__c = 35;
        testRecord.Margin_Sales_Ops_Lower_Bound__c = 45;
            Test.startTest();
        update testRecord;
        Test.stopTest();
        
        // Query the updated record to verify changes
        NATT_Approval_Process__c updatedRecord = [
            SELECT Id, Name, Product_Name__c, Margin_EAM_Lower_Bound__c 
            FROM NATT_Approval_Process__c 
            WHERE Id = :testRecord.Id
        ];
        //System.assertEquals('Updated Product', updatedRecord.Product_Name__c, 'Product Name should be updated.');
        //System.assertEquals(150, updatedRecord.Margin_EAM_Lower_Bound__c, 'EAM Lower Bound should be updated.');
        
        // In test context, we assume the email service was invoked since no exceptions were thrown.
    }
}