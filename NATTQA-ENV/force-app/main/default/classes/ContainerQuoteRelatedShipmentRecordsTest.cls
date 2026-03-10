/********************************************************************************************************
* @author         Aman(Deloitte)
* @description    This is a test class for ContainerQuoteRelatedShipmentRecords class code coverage.
* @date           08/01/2022 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Deloitte               08/01/2022                                   Initial version
*********************************************************************************************************/
@isTest
public class ContainerQuoteRelatedShipmentRecordsTest {
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
            newQuote.CONTAINER_Sales_Region__c = 'NAO';
            newQuote.CONTAINER_Type__c = 'Stock Quote';
            //Insert quote new record
            insert newQuote;

            //Create New Shipment Schedule Record with values
            Shipment_Schedule__c newShipmentSchedule = new Shipment_Schedule__c();
            newShipmentSchedule.CONTAINER_Qty__c = 1;
            newShipmentSchedule.CONTAINER_Quote_Number__c = newQuote.id;
            insert newShipmentSchedule;
        } 
    }
    
    @isTest
    static void validateQuoteRelatedShipmentRecords() {
        User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];
        
        System.runAs(containerAdmin) {
            Test.startTest();
            List<SBQQ__Quote__c> quoteID = [select id, CONTAINER_ASO_ID__c from SBQQ__Quote__c];
            ContainerQuoteRelatedShipmentRecords RSD = new ContainerQuoteRelatedShipmentRecords();
            RSD.getShipmentRecords();
            Test.stopTest();
            
            //Validate the changes
        }
    }
    
    @isTest
    static void validateQuoteRelatedShipmentRecords1() {
        User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];
        
        System.runAs(containerAdmin) {
            Test.startTest();
            List<SBQQ__Quote__c> quoteID = [select id, CONTAINER_ASO_ID__c from SBQQ__Quote__c];
            //Id idToPass = quoteID[0].id;
            ContainerQuoteRelatedShipmentRecords RSD = new ContainerQuoteRelatedShipmentRecords();
            RSD.quoteId = quoteID[0].id;
            List<Shipment_Schedule__c> records = RSD.getShipmentRecords();
            Test.stopTest();
            
            //Validate the changes
        }
    }
    
    @isTest
    static void validateQuoteRelatedShipmentRecords2() {
        User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];
        id qteRecTypeID = Schema.SobjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('CONTAINER_NT_Quote').getRecordTypeId();
            SBQQ__Quote__c newQuote = new SBQQ__Quote__c();
            newQuote.RecordTypeId = qteRecTypeID;
            newQuote.CONTAINER_Sales_Region__c = 'NAO';
            newQuote.CONTAINER_Type__c = 'Stock Quote';
            //Insert quote new record
            insert newQuote;
        System.runAs(containerAdmin) {
            Test.startTest();
            ContainerQuoteRelatedShipmentRecords RSD = new ContainerQuoteRelatedShipmentRecords();
            RSD.quoteId = newQuote.id;
            List<Shipment_Schedule__c> records = RSD.getShipmentRecords();
            Test.stopTest();
            
            //Validate the changes
        }
    }
}