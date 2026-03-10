@isTest
public class CONTAINER_Quote_ASO_Release_Helper_Test {
	@testSetup 
    static void setup() {
        
        // This code runs as the system user
        Profile prof = [SELECT Id FROM Profile WHERE Name='CONTAINER Administrator'];
        User newUser = new User(Alias = 'contAdm', Email='contAdmin@carrier.com', LastName='AdminTest', ProfileId = prof.Id, 
                                UserName='testAdminUser@carrier.com', EmailEncodingKey='UTF-8', 
                                LanguageLocaleKey='en_US', LocaleSidKey='en_US', TimeZoneSidKey='America/Los_Angeles');
        insert newUser;
        
        System.runAs(newUser) {
            //CONTAINER_UtilityClass.createCustomerQuote();
        }
    }
   
    @isTest
    static void validatecontainer_Doc1() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        CONTAINER_Quote_ASO_Release_Helper_Test.createCustomerQuoteBulk_Genset();
        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            //quoteList[0].CONTAINER_ASO_ID__c='';
            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            //update quoteList[0];
            List<SBQQ__QuoteDocument__c> lstQD = new List<SBQQ__QuoteDocument__c>();
        	SBQQ__QuoteDocument__c objQD = new SBQQ__QuoteDocument__c();
        	objQD.Name = 'Test Doc 1';
        	objQD.SBQQ__Quote__c = quoteList[0].Id;
        	objQD.SBQQ__Version__c = 1;
        	lstQD.add(objQD);
            insert lstQD;
           
        }
    }
     @isTest
    static void validatecontainer_Doc2() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        CONTAINER_Quote_ASO_Release_Helper_Test.createCustomerQuoteBulk_Genset();
        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_Sales_Region__c=ContainerConstants.NAO;
            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList[0];
            List<SBQQ__QuoteDocument__c> lstQD = new List<SBQQ__QuoteDocument__c>();
        	SBQQ__QuoteDocument__c objQD = new SBQQ__QuoteDocument__c();
        	objQD.Name = 'Test Doc 1';
        	objQD.SBQQ__Quote__c = quoteList[0].Id;
        	objQD.SBQQ__Version__c = 1;
        	lstQD.add(objQD);
            insert lstQD;
           
        }
    }
     @isTest
    static void validatecontainer_Doc3() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        CONTAINER_Quote_ASO_Release_Helper_Test.createCustomerQuoteBulk_Genset();
        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_Sales_Region__c=ContainerConstants.EMEA;
            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList[0];
            List<SBQQ__QuoteDocument__c> lstQD = new List<SBQQ__QuoteDocument__c>();
        	SBQQ__QuoteDocument__c objQD = new SBQQ__QuoteDocument__c();
        	objQD.Name = 'Test Doc 1';
        	objQD.SBQQ__Quote__c = quoteList[0].Id;
        	objQD.SBQQ__Version__c = 1;
        	lstQD.add(objQD);
            insert lstQD;
           
        }
    }
    @isTest
    static void validatecontainer_Doc4() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        CONTAINER_Quote_ASO_Release_Helper_Test.createCustomerQuoteBulk_Genset();
        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            //quoteList[0].CONTAINER_ASO_ID__c='';
            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            //update quoteList[0];
            List<SBQQ__QuoteDocument__c> lstQD = new List<SBQQ__QuoteDocument__c>();
        	SBQQ__QuoteDocument__c objQD = new SBQQ__QuoteDocument__c();
        	objQD.Name = 'Test Doc 1';
        	objQD.SBQQ__Quote__c = quoteList[0].Id;
        	objQD.SBQQ__Version__c = 1;
        	lstQD.add(objQD);
            insert lstQD;
           
        }
    }
     @isTest
    static void validatecontainer_Doc5() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        CONTAINER_Quote_ASO_Release_Helper_Test.createCustomerQuoteBulk_Genset();
        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_Sales_Region__c=ContainerConstants.NAO;
            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList[0];
            List<SBQQ__QuoteDocument__c> lstQD = new List<SBQQ__QuoteDocument__c>();
        	SBQQ__QuoteDocument__c objQD = new SBQQ__QuoteDocument__c();
        	objQD.Name = 'Test Doc 1';
        	objQD.SBQQ__Quote__c = quoteList[0].Id;
        	objQD.SBQQ__Version__c = 1;
        	lstQD.add(objQD);
            insert lstQD;
           
        }
    }
     @isTest
    static void validatecontainer_Doc6() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        CONTAINER_Quote_ASO_Release_Helper_Test.createCustomerQuoteBulk_Genset();
        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_Sales_Region__c=ContainerConstants.EMEA;
            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList[0];
            List<SBQQ__QuoteDocument__c> lstQD = new List<SBQQ__QuoteDocument__c>();
        	SBQQ__QuoteDocument__c objQD = new SBQQ__QuoteDocument__c();
        	objQD.Name = 'Test Doc 1';
        	objQD.SBQQ__Quote__c = quoteList[0].Id;
        	objQD.SBQQ__Version__c = 1;
        	lstQD.add(objQD);
            insert lstQD;
           
        }
    }
      @isTest
    static void validatecontainer_Doc7() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        CONTAINER_Quote_ASO_Release_Helper_Test.createCustomerQuoteBulk_Genset();
        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_Sales_Region__c=ContainerConstants.APO;
            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList[0];
            List<SBQQ__QuoteDocument__c> lstQD = new List<SBQQ__QuoteDocument__c>();
        	SBQQ__QuoteDocument__c objQD = new SBQQ__QuoteDocument__c();
        	objQD.Name = 'Test Doc 1';
        	objQD.SBQQ__Quote__c = quoteList[0].Id;
        	objQD.SBQQ__Version__c = 1;
        	lstQD.add(objQD);
            insert lstQD;
           
        }
    }
  @isTest
    static void validatecontainer_Doc8() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        CONTAINER_Quote_ASO_Release_Helper_Test.createCustomerQuoteBulk_Genset();
        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_Sales_Region__c=ContainerConstants.APO;
            quoteList[0].CONTAINER_ASO_Rev__c='1';
            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList[0];
            List<SBQQ__QuoteDocument__c> lstQD = new List<SBQQ__QuoteDocument__c>();
        	SBQQ__QuoteDocument__c objQD = new SBQQ__QuoteDocument__c();
        	objQD.Name = 'Test Doc 1';
        	objQD.SBQQ__Quote__c = quoteList[0].Id;
        	objQD.SBQQ__Version__c = 1;
            //objQD.SBQQ__DocumentId__c ='test';
        	lstQD.add(objQD);
            insert lstQD;
           
        }
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
           // newQuote.CONTAINER_Job__c = 'Ref3456';
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
}