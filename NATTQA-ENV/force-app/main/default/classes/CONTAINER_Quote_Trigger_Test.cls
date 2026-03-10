/********************************************************************************************************
* @author         Deloitte
* @description    This is a test class for CONTAINER_Quote_Trigger_Helper class code coverage.
* @date           09/03/2022 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Deloitte               09/03/2022                                   Initial version
*********************************************************************************************************/
@isTest
public class CONTAINER_Quote_Trigger_Test {
    
    //Test data created to handle the process
    @testSetup 
    static void setup() {
        //Query Sales RSM Role
        UserRole RSMRole = [SELECT Id FROM UserRole where Name = 'Container Sales RSM NAO' ];
        
        // Create users with public group and role
        Profile prof = [SELECT Id FROM Profile WHERE Name='CONTAINER Administrator'];
        User newUserWithGroup = new User(Alias = 'contAdm', Email='contAdmin@carrier.com', LastName='AdminTest', ProfileId = prof.Id, 
                                         UserName='testAdminUser@carrier.com', EmailEncodingKey='UTF-8', 
                                         LanguageLocaleKey='en_US', LocaleSidKey='en_US', TimeZoneSidKey='America/Los_Angeles', UserRoleId = RSMRole.Id);
        insert newUserWithGroup;
        Group salesVP = [ Select Id  From Group Where DeveloperName = 'CONTAINER_Sales_VP_Approval_NT_Quote'];
        GroupMember salesVPGM = new GroupMember(GroupId = salesVP.Id, UserOrGroupId = newUserWithGroup.Id);
        insert salesVPGM;
        Group salesVP2 = [ Select Id  From Group Where DeveloperName = 'CONTAINER_Sales_CAM_Approval_NT_Quote'];  
        GroupMember salesVP2GM = new GroupMember(GroupId = salesVP2.Id, UserOrGroupId = newUserWithGroup.Id);
        insert salesVP2GM;
        Group salesVP3 = [ Select Id  From Group Where DeveloperName = 'CONTAINER_Sales_PM_Approval_NT_Quote'];   
        GroupMember salesVP3GM = new GroupMember(GroupId = salesVP3.Id, UserOrGroupId = newUserWithGroup.Id);
        insert salesVP3GM;
        
        
        //User without any public group
        User newUserWithoutGroup = new User(Alias = 'contAdm2', Email='contAdmin2@carrier.com', LastName='AdminTest2', ProfileId = prof.Id, 
                                            UserName='testAdminUser2@carrier.com', EmailEncodingKey='UTF-8', 
                                            LanguageLocaleKey='en_US', LocaleSidKey='en_US', TimeZoneSidKey='America/Los_Angeles');
        insert newUserWithoutGroup;
        Group salesVP4 = [ Select Id  From Group Where DeveloperName = 'CONTAINER_Sales_CAM_Approvl_GENSET_Quote'];   
        GroupMember salesVP4GM = new GroupMember(GroupId = salesVP4.Id, UserOrGroupId = newUserWithoutGroup.Id);
        insert salesVP4GM;
        Group salesVP5 = [ Select Id  From Group Where DeveloperName = 'CONTAINER_Sales_RSM_Accep_GENSET_Quote'];   
        GroupMember salesVP5GM = new GroupMember(GroupId = salesVP5.Id, UserOrGroupId = newUserWithoutGroup.Id);
        insert salesVP5GM;
        Group salesVP6 = [ Select Id  From Group Where DeveloperName = 'CONTAINER_Sales_VP_Approval_GENSET_Quote'];
        GroupMember salesVP6GM = new GroupMember(GroupId = salesVP6.Id, UserOrGroupId = newUserWithoutGroup.Id);
        insert salesVP6GM;
        System.runAs(newUserWithGroup) {
            CONTAINER_UtilityClass.createCustomerQuote();
        }
    }
    
    @isTest
    static void validatePendingStatusPositiveSce() {
        User VPApprovalUser = [select id from user where Alias = 'contAdm' limit 1];
        User PMApproalUser = [select id from user where Alias = 'contAdm2' limit 1];
        List<SBQQ__Quote__c> updateQuote2 = new List<SBQQ__Quote__c>();
        Test.startTest();
        //Update quote record as VP Sales approver
        System.runAs(VPApprovalUser) {
            
            List<SBQQ__Quote__c> updateQuote = [select id, ApprovalStatus__c, CONTAINER_Payment_Terms__c from SBQQ__Quote__c where CONTAINER_ASO_ID__c = '3415'];
            //updateQuote[0].CONTAINER_Payment_Terms__c = 'Not Applicable - N/A';
            updateQuote[0].ApprovalStatus__c = 'Pending';
            update updateQuote;
            
            updateQuote[0].CONTAINER_Status__c = 'Pending RSM Acceptance for Special Req';
            update updateQuote;
           
            updateQuote[0].CONTAINER_Status__c = 'Pending PM Approval';
            update updateQuote;
            
            updateQuote[0].ApprovalStatus__c = 'Recalled';
           // updateQuote[0].Container_Factory_Rework_Comments__c = 'ReTest';
            update updateQuote;
            
        }
        
        //Update Quote as RSM Sales User
        System.runAs(PMApproalUser) {
            String GENSETRecord = Schema.getGlobalDescribe().get('SBQQ__Quote__c').getDescribe().getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            String NTRecord = Schema.getGlobalDescribe().get('SBQQ__Quote__c').getDescribe().getRecordTypeInfosByName().get('Container NT Quote').getRecordTypeId();
            updateQuote2 = [select id, ApprovalStatus__c, CONTAINER_Payment_Terms__c, CONTAINER_Sales_Region__c, RecordTypeId from SBQQ__Quote__c where CONTAINER_ASO_ID__c = '3415'];
            
            updateQuote2[0].Container_Factory_Rework_Comments__c = 'ReTest';
            updateQuote2[0].CONTAINER_Job__c = null;
            update updateQuote2;
            
            updateQuote2[0].CONTAINER_Sales_Region__c = 'NAO';
            updateQuote2[0].CONTAINER_Payment_Terms__c = 'NOT APPLICABLE - NAO';
            updateQuote2[0].RecordTypeId = GENSETRecord;
            update updateQuote2;
            
            updateQuote2[0].CONTAINER_Status__c = 'Pending RSM Acceptance for Prod & Ship Schedule';
            update updateQuote2;
            
            updateQuote2[0].Container_Factory_Rework_Comments__c = 'RedoTest';
            updateQuote2[0].CONTAINER_Status__c = 'Pending CAM Approval';
            update updateQuote2;
            
            updateQuote2[0].Container_Factory_Rework_Comments__c = 'RedoTest2';
            update updateQuote2;
            
            updateQuote2[0].CONTAINER_Sales_Region__c = 'APO';
            updateQuote2[0].CONTAINER_Payment_Terms__c = 'Not Applicable - N/A';
            updateQuote2[0].RecordTypeId = NTRecord;
            update updateQuote2;
            
            updateQuote2[0].CONTAINER_Status__c = 'Pending CAM Approval';
            update updateQuote2;
            
            updateQuote2[0].Container_Factory_Rework_Comments__c = 'ReworkTest';
            updateQuote2[0].ApprovalStatus__c = 'Approved';
            update updateQuote2;
        }
        Test.stopTest();
        
        //Get list of updated quote record.
        List<SBQQ__Quote__c> quoteRecordID = [select id, ApprovalStatus__c, CONTAINER_Payment_Terms__c from SBQQ__Quote__c where id =:updateQuote2[0].id];
        system.assertEquals(quoteRecordID[0].ApprovalStatus__c, 'Approved', 'Error while Asserting Record');
    }
    
    @isTest
    static void validatePendingStatusPositiveSce2() {
        User VPApprovalUser = [select id from user where Alias = 'contAdm' limit 1];
        User PMApproalUser = [select id from user where Alias = 'contAdm2' limit 1];
        List<SBQQ__Quote__c> updateQuote2 = new List<SBQQ__Quote__c>();
        Test.startTest();
        
        //Update Quote as RSM Sales User
        System.runAs(PMApproalUser) {
            String GENSETRecord = Schema.getGlobalDescribe().get('SBQQ__Quote__c').getDescribe().getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            String NTRecord = Schema.getGlobalDescribe().get('SBQQ__Quote__c').getDescribe().getRecordTypeInfosByName().get('Container NT Quote').getRecordTypeId();
            updateQuote2 = [select id, ApprovalStatus__c, CONTAINER_Payment_Terms__c, CONTAINER_Sales_Region__c, RecordTypeId from SBQQ__Quote__c where CONTAINER_ASO_ID__c = '3415'];
            
            updateQuote2[0].CONTAINER_Sales_Region__c = 'NAO';
            updateQuote2[0].CONTAINER_Payment_Terms__c = 'NOT APPLICABLE - NAO';
            updateQuote2[0].CONTAINER_Job__c = null;
            updateQuote2[0].ApprovalStatus__c = 'Pending';
            updateQuote2[0].RecordTypeId = GENSETRecord;
            update updateQuote2;
            
            updateQuote2[0].CONTAINER_Status__c = 'Pending RSM Acceptance for Special Req';
            update updateQuote2;
            
            updateQuote2[0].Container_Factory_Rework_Comments__c = 'RedoTest';
            updateQuote2[0].CONTAINER_Status__c = 'Pending CAM Approval';
            update updateQuote2;
            
            updateQuote2[0].Container_Factory_Rework_Comments__c = 'ReworkTest';
            updateQuote2[0].ApprovalStatus__c = 'Approved';
            update updateQuote2;
        }
        Test.stopTest();
        
        //Get list of updated quote record.
        List<SBQQ__Quote__c> quoteRecordID = [select id, ApprovalStatus__c, CONTAINER_Payment_Terms__c from SBQQ__Quote__c where id =:updateQuote2[0].id];
        system.assertEquals(quoteRecordID[0].ApprovalStatus__c, 'Approved', 'Error while Asserting Record');
    }
}