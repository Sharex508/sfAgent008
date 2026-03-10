/********************************************************************************************************
* @author         Aman(Deloitte)
* @description    This is a test class for CONTAINER_Quote_ASO_Reset class code coverage.
* @date           08/01/2022 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Deloitte               08/01/2022                                   Initial version
*********************************************************************************************************/
@isTest
public class CONTAINER_Quote_ASO_Reset_Test {
    
    @testSetup 
    static void setup() {
        // This code runs as the system user
        Profile prof = [SELECT Id FROM Profile WHERE Name='CONTAINER Administrator'];
        User newUser = new User(Alias = 'contAdm', Email='contAdmin@carrier.com', LastName='AdminTest', ProfileId = prof.Id, 
                                UserName='testAdminUser@carrier.com', EmailEncodingKey='UTF-8', 
                                LanguageLocaleKey='en_US', LocaleSidKey='en_US', TimeZoneSidKey='America/Los_Angeles');
        insert newUser;
        
        System.runAs(newUser) {
    
            //Create New Quote Record with values
            id qteRecTypeID = Schema.SobjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('CONTAINER_NT_Quote').getRecordTypeId();
            SBQQ__Quote__c newQuote = new SBQQ__Quote__c();
            newQuote.RecordTypeId = qteRecTypeID;
            newQuote.CONTAINER_ASO_ID__c = '1';
            newQuote.CONTAINER_ASO_Rev__c = 'B';
            newQuote.CONTAINER_Sales_Region__c = 'NAO';
            newQuote.CONTAINER_Type__c = 'Stock Quote';
            newQuote.CONTAINER_NT_RevNumber__c = 1;
            //Insert quote new record
            insert newQuote;
            
            id qteRecTypeID1 = Schema.SobjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('CONTAINER_GENSET_Quote').getRecordTypeId();
            SBQQ__Quote__c newQuote1 = new SBQQ__Quote__c();
            newQuote1.RecordTypeId = qteRecTypeID1;
            newQuote1.CONTAINER_ASO_ID__c = '1';
            newQuote1.CONTAINER_ASO_Rev__c = 'B';
            newQuote1.CONTAINER_Sales_Region__c = 'NAO';
            newQuote1.CONTAINER_Type__c = 'Stock Quote';
            newQuote1.CONTAINER_GENSET_RevNumber__c = 1;
            //Insert quote new record
            insert newQuote1;
            
            id qteRecTypeID2 = Schema.SobjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('CONTAINER_GENSET_Quote').getRecordTypeId();
            SBQQ__Quote__c newQuote2 = new SBQQ__Quote__c();
            newQuote2.RecordTypeId = qteRecTypeID2;
            newQuote2.CONTAINER_ASO_ID__c = '';
            newQuote2.CONTAINER_ASO_Rev__c = '';
            newQuote2.CONTAINER_Sales_Region__c = 'NAO';
            newQuote2.CONTAINER_Type__c = 'Stock Quote';
            //newQuote2.CONTAINER_GENSET_RevNumber__c = 1;
            //Insert quote new record
            insert newQuote2;
            
            id qteRecTypeID3 = Schema.SobjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('CONTAINER_NT_Quote').getRecordTypeId();
            SBQQ__Quote__c newQuote3 = new SBQQ__Quote__c();
            newQuote3.RecordTypeId = qteRecTypeID3;
            newQuote3.CONTAINER_ASO_ID__c = '';
            newQuote3.CONTAINER_ASO_Rev__c = '';
            newQuote3.CONTAINER_Sales_Region__c = 'NAO';
            newQuote3.CONTAINER_Type__c = 'Stock Quote';
            //newQuote2.CONTAINER_NT_RevNumber__c = 1;
            //Insert quote new record
            insert newQuote3;
            
        } 
    }
    
    @isTest
    static void validateQuoteResetButton() {
        User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];
        
        System.runAs(containerAdmin) {
            Test.startTest();
            List<SBQQ__Quote__c> quoteID = [select id, CONTAINER_ASO_ID__c, CONTAINER_ASO_Rev__c,CONTAINER_NT_RevNumber__c from SBQQ__Quote__c WHERE RecordType.DeveloperName = 'CONTAINER_NT_Quote'];
            ApexPages.StandardController sc = new ApexPages.StandardController(quoteID[0]);
            CONTAINER_Quote_ASO_Reset reset = new CONTAINER_Quote_ASO_Reset(sc);
            reset.onReset();
            Test.stopTest();
            
            
            //Validate the changes
            //system.assertEquals(quoteID[0].CONTAINER_ASO_Rev__c, 'B', 'Error while Asserting Record');
        }
    }
    @isTest
    static void validateQuoteResetButton1() {
        User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];
        
        System.runAs(containerAdmin) {
            Test.startTest();
            List<SBQQ__Quote__c> quoteID = [select id, CONTAINER_ASO_ID__c, CONTAINER_ASO_Rev__c,CONTAINER_NT_RevNumber__c from SBQQ__Quote__c WHERE RecordType.DeveloperName = 'CONTAINER_NT_Quote'];
            //if(quoteID[0].RecordType.DeveloperName = 'CONTAINER_NT_Quote'){
                quoteID[0].CONTAINER_ASO_Rev__c = 'A';
                quoteID[0].CONTAINER_ASO_ID__c = '0';
                quoteID[0].CONTAINER_NT_RevNumber__c = 0;
                update quoteID[0];
                ApexPages.StandardController sc = new ApexPages.StandardController(quoteID[0]);
                CONTAINER_Quote_ASO_Reset reset = new CONTAINER_Quote_ASO_Reset(sc);
                reset.onReset();
                Test.stopTest();
        
            
            
            //Validate the changes
            //system.assertEquals(quoteID[0].CONTAINER_ASO_Rev__c, 'A', 'Error while Asserting Record');
        }
    }
    
    @isTest
    static void validateQuoteResetButton2() {
        User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];
        
        System.runAs(containerAdmin) {
            Test.startTest();
            List<SBQQ__Quote__c> quoteID = [select id, CONTAINER_ASO_ID__c, CONTAINER_ASO_Rev__c,CONTAINER_NT_RevNumber__c from SBQQ__Quote__c WHERE RecordType.DeveloperName = 'CONTAINER_NT_Quote' AND CONTAINER_ASO_ID__c = '' AND CONTAINER_ASO_Rev__c = ''];
            ApexPages.StandardController sc = new ApexPages.StandardController(quoteID[0]);
            CONTAINER_Quote_ASO_Reset reset = new CONTAINER_Quote_ASO_Reset(sc);
            reset.onReset();
            Test.stopTest();
            
            
            //Validate the changes
            //system.assertEquals(quoteID[0].CONTAINER_ASO_Rev__c, 'B', 'Error while Asserting Record');
        }
    }
    
    @isTest
    static void validateQuoteResetButton3() {
        User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];
        
        System.runAs(containerAdmin) {
            Test.startTest();
            List<SBQQ__Quote__c> quoteID = [select id, CONTAINER_ASO_ID__c, CONTAINER_ASO_Rev__c,CONTAINER_GENSET_RevNumber__c from SBQQ__Quote__c WHERE RecordType.DeveloperName = 'CONTAINER_GENSET_Quote'];
            ApexPages.StandardController sc = new ApexPages.StandardController(quoteID[0]);
            CONTAINER_Quote_ASO_Reset reset = new CONTAINER_Quote_ASO_Reset(sc);
            reset.onReset();
            Test.stopTest();
            
            
            //Validate the changes
            //system.assertEquals(quoteID[0].CONTAINER_ASO_Rev__c, 'B', 'Error while Asserting Record');
        }
    }
    
    @isTest
    static void validateQuoteResetButton4() {
        User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];
        
        System.runAs(containerAdmin) {
            Test.startTest();
            List<SBQQ__Quote__c> quoteID = [select id, CONTAINER_ASO_ID__c, CONTAINER_ASO_Rev__c,CONTAINER_GENSET_RevNumber__c from SBQQ__Quote__c WHERE RecordType.DeveloperName = 'CONTAINER_GENSET_Quote'];
            //if(quoteID[0].RecordType.DeveloperName = 'CONTAINER_NT_Quote'){
                quoteID[0].CONTAINER_ASO_Rev__c = 'A';
                quoteID[0].CONTAINER_ASO_ID__c = '0';
                quoteID[0].CONTAINER_NT_RevNumber__c = 0;
                update quoteID[0];
                ApexPages.StandardController sc = new ApexPages.StandardController(quoteID[0]);
                CONTAINER_Quote_ASO_Reset reset = new CONTAINER_Quote_ASO_Reset(sc);
                reset.onReset();
                Test.stopTest();
        
            
            
            //Validate the changes
            //system.assertEquals(quoteID[0].CONTAINER_ASO_Rev__c, 'A', 'Error while Asserting Record');
        }
    }
    
    @isTest
    static void validateQuoteResetButton5() {
        User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];
        
        System.runAs(containerAdmin) {
            Test.startTest();
            List<SBQQ__Quote__c> quoteID = [select id, CONTAINER_ASO_ID__c, CONTAINER_ASO_Rev__c,CONTAINER_GENSET_RevNumber__c from SBQQ__Quote__c WHERE RecordType.DeveloperName = 'CONTAINER_GENSET_Quote' AND CONTAINER_ASO_ID__c = '' AND CONTAINER_ASO_Rev__c = ''];
            ApexPages.StandardController sc = new ApexPages.StandardController(quoteID[0]);
            CONTAINER_Quote_ASO_Reset reset = new CONTAINER_Quote_ASO_Reset(sc);
            reset.onReset();
            Test.stopTest();
            
            
            //Validate the changes
            //system.assertEquals(quoteID[0].CONTAINER_ASO_Rev__c, 'B', 'Error while Asserting Record');
        }
    }
}