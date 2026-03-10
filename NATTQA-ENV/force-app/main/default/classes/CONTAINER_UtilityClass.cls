/********************************************************************************************************
* @author         (Deloitte)
* @description    This is a test class for CONTAINERQuoteSnapshotReview class code coverage.
* @date           09/02/2022 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Deloitte               09/02/2022                                  Initial version
*********************************************************************************************************/

@isTest
public with sharing class CONTAINER_UtilityClass {
    
    
    public static void createCustomerQuote(){
        //creating account record-
            id accRecTypeID = Schema.SobjectType.Account.getRecordTypeInfosByDeveloperName().get('CONTAINER_Customer').getRecordTypeId();
            Account acc = new Account();
            acc.Name = 'Test AccASOReview'; 
            acc.RecordTypeId = accRecTypeID;
            insert acc; 
            
            //creating product record-
            Product2 p = new Product2();
            p.Name = ' Test ProdASOReview ';
            p.Description='Test Product Entry For Product';
            p.productCode = 'SJ PD 1';
            p.isActive = true;
            insert p;
            
            // insert pricebook entry for the product
            Id pricebookId = Test.getStandardPricebookId();
            PricebookEntry pbe = new PricebookEntry(Product2Id = p.Id, pricebook2Id = pricebookId, unitprice=100, isActive=true);
            insert pbe;
            
            //creating opportunity record-
            id oppRecTypeID = Schema.SobjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('CONTAINER_Opportunity').getRecordTypeId();
            Opportunity opp = new Opportunity();
            opp.RecordTypeId = oppRecTypeID;
            opp.AccountId = acc.Id;
            opp.Name = 'test opp';
            opp.CloseDate= System.Today();
            opp.StageName='new';
            opp.Pricebook2Id = Test.getStandardPricebookId();
            insert opp;
            
            //Create New Quote Record with values
            id qteRecTypeID = Schema.SobjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('CONTAINER_NT_Quote').getRecordTypeId();
            SBQQ__Quote__c newQuote = new SBQQ__Quote__c();
            newQuote.RecordTypeId = qteRecTypeID;
            newQuote.SBQQ__Opportunity2__c = opp.Id;
            newQuote.CONTAINER_ASO_ID__c = '3415';
            //newQuote.CONTAINER_Job__c = 'Ref3456';
            newQuote.CONTAINER_Qty__c = 34;
            newQuote.CONTAINER_Model_Number__c = 'ert';
            newQuote.CONTAINER_PID__c = '34er';
            newQuote.CONTAINER_Sales_Region__c = 'APO';
            newQuote.Factory_Rework_CONTAINER__c = 'Test';
            newQuote.Container_Factory_Rework_Comments__c = 'Test';
            newQuote.CONTAINER_Commissioning_Work_Order_Info__c ='Test';
            newQuote.Container_Commissioning_WO_Comments__c ='Test';
            newQuote.CONTAINER_Payment_Terms__c = 'Not Applicable - N/A';
            newQuote.CONTAINER_Status__c = 'Pending VP Approval';
            //Insert quote new record
            insert newQuote;
            
             
            //creating quoteline items records-
            SBQQ__QuoteLine__c qtLine = new SBQQ__QuoteLine__c();
            qtLine.SBQQ__Bundle__c = true;
            qtLine.NATT_P_N__c = 'SPARE PARTS';
            qtLine.SBQQ__Quote__c = [select id from SBQQ__Quote__c limit 1].Id;
            qtLine.SBQQ__Product__c = [select id from Product2 limit 1].Id;
            insert qtLine;
            
            //Query the Id and add it on the list.
            List<SBQQ__Quote__c> quoteID = [select id from SBQQ__Quote__c where CONTAINER_ASO_ID__c ='3415'];
            
            CONTAINER_Quote_Snapshot__c newQuoteSnapshotRec = new CONTAINER_Quote_Snapshot__c();
            newQuoteSnapshotRec.CONTAINER_Quote__c = quoteID[0].id;
            insert newQuoteSnapshotRec; 
    }
    public static void createCustomerQuoteBulk_Genset(){
        //creating account record-
            id accRecTypeID = Schema.SobjectType.Account.getRecordTypeInfosByDeveloperName().get('CONTAINER_Customer').getRecordTypeId();
            Account acc = new Account();
            acc.Name = 'Test AccASOReview'; 
            acc.RecordTypeId = accRecTypeID;
            insert acc; 
            
            //creating product record-
            Product2 p = new Product2();
            p.Name = ' Test ProdASOReview ';
            p.Description='Test Product Entry For Product';
            p.productCode = 'SJ PD 1';
            p.isActive = true;
            insert p;
            
            // insert pricebook entry for the product
            Id pricebookId = Test.getStandardPricebookId();
            PricebookEntry pbe = new PricebookEntry(Product2Id = p.Id, pricebook2Id = pricebookId, unitprice=100, isActive=true);
            insert pbe;
            
            //creating opportunity record-
            id oppRecTypeID = Schema.SobjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('CONTAINER_Opportunity').getRecordTypeId();
            Opportunity opp = new Opportunity();
            opp.RecordTypeId = oppRecTypeID;
            opp.AccountId = acc.Id;
            opp.Name = 'test opp';
            opp.CloseDate= System.Today();
            opp.StageName='new';
            opp.Pricebook2Id = Test.getStandardPricebookId();
            insert opp;
            List<SBQQ__Quote__c>quoteList = new List<SBQQ__Quote__c>();
            //Create New Quote Record with values
        for (Integer i=0;i<3;i++){
            id qteRecTypeID = Schema.SobjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('CONTAINER_NT_Quote').getRecordTypeId();
            SBQQ__Quote__c newQuote = new SBQQ__Quote__c();
            newQuote.RecordTypeId = qteRecTypeID;
            newQuote.SBQQ__Opportunity2__c = opp.Id;
            newQuote.CONTAINER_ASO_ID__c = '3'+i;
            if(i==1){
                newQuote.CONTAINER_NT_Previous_ASO_ID__c='12';
            }
            //newQuote.CONTAINER_Job__c = 'Ref3456';
            newQuote.CONTAINER_Qty__c = 34;
            newQuote.CONTAINER_Model_Number__c = 'ert';
            newQuote.CONTAINER_PID__c = '34er';
            newQuote.CONTAINER_Sales_Region__c = 'APO';
            newQuote.Factory_Rework_CONTAINER__c = 'Test';
            newQuote.Container_Factory_Rework_Comments__c = 'Test';
            newQuote.CONTAINER_Commissioning_Work_Order_Info__c ='Test';
            newQuote.Container_Commissioning_WO_Comments__c ='Test';
            newQuote.CONTAINER_Status__c = 'Pending VP Approval';
            //Insert quote new record
            quoteList.add(newQuote);
        	}
            insert quoteList;
            
            //creating quoteline items records-
            /*SBQQ__QuoteLine__c qtLine = new SBQQ__QuoteLine__c();
            qtLine.SBQQ__Bundle__c = true;
            qtLine.NATT_P_N__c = 'SPARE PARTS';
            qtLine.SBQQ__Quote__c = [select id from SBQQ__Quote__c limit 1].Id;
            qtLine.SBQQ__Product__c = [select id from Product2 limit 1].Id;
            insert qtLine;
            
            //Query the Id and add it on the list.
            List<SBQQ__Quote__c> quoteID = [select id from SBQQ__Quote__c where CONTAINER_ASO_ID__c ='3415'];
            
            CONTAINER_Quote_Snapshot__c newQuoteSnapshotRec = new CONTAINER_Quote_Snapshot__c();
            newQuoteSnapshotRec.CONTAINER_Quote__c = quoteID[0].id;
            insert newQuoteSnapshotRec; */
    }
    public static void createCustomerQuoteBulk_NT(){
        //creating account record-
            id accRecTypeID = Schema.SobjectType.Account.getRecordTypeInfosByDeveloperName().get('CONTAINER_Customer').getRecordTypeId();
            Account acc = new Account();
            acc.Name = 'Test AccASOReview'; 
            acc.RecordTypeId = accRecTypeID;
            insert acc; 
            
            //creating product record-
            Product2 p = new Product2();
            p.Name = ' Test ProdASOReview ';
            p.Description='Test Product Entry For Product';
            p.productCode = 'SJ PD 1';
            p.isActive = true;
            insert p;
            
            // insert pricebook entry for the product
            Id pricebookId = Test.getStandardPricebookId();
            PricebookEntry pbe = new PricebookEntry(Product2Id = p.Id, pricebook2Id = pricebookId, unitprice=100, isActive=true);
            insert pbe;
            
            //creating opportunity record-
            id oppRecTypeID = Schema.SobjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('CONTAINER_Opportunity').getRecordTypeId();
            Opportunity opp = new Opportunity();
            opp.RecordTypeId = oppRecTypeID;
            opp.AccountId = acc.Id;
            opp.Name = 'test opp';
            opp.CloseDate= System.Today();
            opp.StageName='new';
            opp.Pricebook2Id = Test.getStandardPricebookId();
            insert opp;
            List<SBQQ__Quote__c>quoteList = new List<SBQQ__Quote__c>();
            //Create New Quote Record with values
        for (Integer i=0;i<3;i++){
            id qteRecTypeID = Schema.SobjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('CONTAINER_GENSET_Quote').getRecordTypeId();
            SBQQ__Quote__c newQuote = new SBQQ__Quote__c();
            newQuote.RecordTypeId = qteRecTypeID;
            newQuote.SBQQ__Opportunity2__c = opp.Id;
            newQuote.CONTAINER_ASO_ID__c = '3'+i;
            if(i==1){
                newQuote.CONTAINER_NT_Previous_ASO_ID__c='12';
            }
            newQuote.CONTAINER_Job__c = 'Ref3456';
            newQuote.CONTAINER_Qty__c = 34;
            newQuote.CONTAINER_Model_Number__c = 'ert';
            newQuote.CONTAINER_PID__c = '34er';
            newQuote.CONTAINER_Sales_Region__c = 'APO';
            newQuote.Factory_Rework_CONTAINER__c = 'Test';
            newQuote.Container_Factory_Rework_Comments__c = 'Test';
            newQuote.CONTAINER_Commissioning_Work_Order_Info__c ='Test';
            newQuote.Container_Commissioning_WO_Comments__c ='Test';
            newQuote.CONTAINER_Status__c = 'SO Released';
            //Insert quote new record
            quoteList.add(newQuote);
        	}
            insert quoteList;
            
            //creating quoteline items records-
            /*SBQQ__QuoteLine__c qtLine = new SBQQ__QuoteLine__c();
            qtLine.SBQQ__Bundle__c = true;
            qtLine.NATT_P_N__c = 'SPARE PARTS';
            qtLine.SBQQ__Quote__c = [select id from SBQQ__Quote__c limit 1].Id;
            qtLine.SBQQ__Product__c = [select id from Product2 limit 1].Id;
            insert qtLine;
            
            //Query the Id and add it on the list.
            List<SBQQ__Quote__c> quoteID = [select id from SBQQ__Quote__c where CONTAINER_ASO_ID__c ='3415'];
            
            CONTAINER_Quote_Snapshot__c newQuoteSnapshotRec = new CONTAINER_Quote_Snapshot__c();
            newQuoteSnapshotRec.CONTAINER_Quote__c = quoteID[0].id;
            insert newQuoteSnapshotRec; */
    }
}