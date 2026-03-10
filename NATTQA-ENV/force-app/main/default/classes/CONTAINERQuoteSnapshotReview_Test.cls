/********************************************************************************************************
* @author         Deloitte
* @description    This is a test class for CONTAINERQuoteSnapshotReview class code coverage.
* @date           08/01/2022 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Deloitte               08/01/2022                                   Initial version
*********************************************************************************************************/
@isTest
public class CONTAINERQuoteSnapshotReview_Test {
    
    //Test data created to handle the process
    @testSetup 
    static void setup() {
        
        // This code runs as the system user
        Profile prof = [SELECT Id FROM Profile WHERE Name='CONTAINER Administrator'];
        User newUser = new User(Alias = 'contAdm', Email='contAdmin@carrier.com', LastName='AdminTest', ProfileId = prof.Id, 
                                UserName='testAdminUser@carrier.com', EmailEncodingKey='UTF-8', 
                                LanguageLocaleKey='en_US', LocaleSidKey='en_US', TimeZoneSidKey='America/Los_Angeles');
        insert newUser;
        
        System.runAs(newUser) {
            CONTAINER_UtilityClass.createCustomerQuote();
        }
    }
    
    
    @isTest
    static void validateQuoteSnapshotReport() {
        User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];
        
        System.runAs(containerAdmin) {
            Test.startTest();
            CONTAINERQuoteSnapshotReview.deleteQuoteSnapshotRecords();
            
            Test.stopTest();
            
            List<SBQQ__Quote__c> updateQuote = [select id, CONTAINER_ASO_ID__c from SBQQ__Quote__c where CONTAINER_ASO_ID__c = '3415'];
            //Validate the changes
            system.assertEquals(updateQuote[0].CONTAINER_ASO_ID__c, '3415', 'Error while Asserting Record');
        }
    }
    
    @isTest
    static void validateQuoteSnapshotRecCreation() {
        User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];
        
        System.runAs(containerAdmin) {
            Test.startTest();
            List<SBQQ__Quote__c> updateQuote = [select id, ApprovalStatus__c, CONTAINER_Payment_Terms__c from SBQQ__Quote__c where CONTAINER_ASO_ID__c = '3415'];
            CONTAINERQuoteSnapshotReview.Processbatch(updateQuote);
            Test.stopTest();
            
            List<CONTAINER_Quote_Snapshot__c> quoteSnapshotID = [select id, CONTAINER_ASO_Number__c from CONTAINER_Quote_Snapshot__c];
            //Validate the changes
            system.assertEquals(quoteSnapshotID[0].CONTAINER_ASO_Number__c, '3415', 'Error while Asserting Record');
        }
    }
    
     @isTest
    static void validateQuoteSnapshotRecBatchClass() {
        User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];
        
        System.runAs(containerAdmin) {
            Test.startTest();
               CONTAINERQuoteSnapshotBatchClass sch = new CONTAINERQuoteSnapshotBatchClass();
               Id batchJobId = Database.executeBatch(sch, 50);
            Test.stopTest();
            
            List<AsyncApexJob> bacthJobRec = [SELECT Id FROM AsyncApexJob WHERE Id =:batchJobId];
            //Validate the changes
            system.assertEquals(bacthJobRec[0].Id, batchJobId, 'Error while Asserting Record');
        }
    }
    
    @isTest
    static void validateQuoteSnapshotRecBatchScheduler() {
        User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];
        
        System.runAs(containerAdmin) {
            Test.startTest();
               String CRON_EXP = '0 0 * * * ?';
               CONTAINERQuoteSnapshotBatchClass sch = new CONTAINERQuoteSnapshotBatchClass();
               system.schedule('Hourly Example Batch Schedule job', CRON_EXP, sch);
            Test.stopTest();
            
            List<SBQQ__Quote__c> updateQuote = [select id, CONTAINER_ASO_ID__c from SBQQ__Quote__c where CONTAINER_ASO_ID__c = '3415'];
            //Validate the changes
            system.assertEquals(updateQuote[0].CONTAINER_ASO_ID__c, '3415', 'Error while Asserting Record');
        }
    }
}