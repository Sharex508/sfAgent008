/********************************************************************************************************
* @author         Deloitte
* @description    Test class for QuoteExtController class.
* @date           09/02/2022 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Deloitte               09/02/2022                                   Initial version
*********************************************************************************************************/
@isTest
public class CONTAINER_QuoteExtControllerTest {

    @isTest
    public static void onSubmitTest(){
        test.startTest();
            PageReference pageRef = Page.SubmitQuote;
        	CONTAINER_UtilityClass.createCustomerQuote();
        	//Query the Id and add it on the list.
            List<SBQQ__Quote__c> quoteID = [select id from SBQQ__Quote__c where CONTAINER_ASO_ID__c ='3415'];
        
            Test.setCurrentPage(pageRef);
            pageRef.getParameters().put('Id',quoteID[0].id);
            ApexPages.StandardController sc = new ApexPages.StandardController(quoteID[0]);
            QuoteExtController controller = new QuoteExtController(sc);
        	controller.onSubmit();
            //System.assertNotEquals(null,controller.autoRun());
        
        test.stopTest();
    }
    
    @isTest
    public static void onSubmitTestV1(){
        test.startTest();
            PageReference pageRef = Page.SubmitQuote;
        	CONTAINER_UtilityClass.createCustomerQuote();
        	//Query the Id and add it on the list.
        	Opportunity opp = [Select id, name from opportunity limit 1];
        
            id qteRecTypeID = Schema.SobjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('CONTAINER_NT_Quote').getRecordTypeId();
            SBQQ__Quote__c newQuote = new SBQQ__Quote__c();
            newQuote.RecordTypeId = qteRecTypeID;
            newQuote.SBQQ__Opportunity2__c = opp.Id;
            newQuote.CONTAINER_Sales_Region__c = 'APO';
        	newQuote.CONTAINER_Qty__c = 2;
        	newQuote.CONTAINER_Type__c = 'End Customer Quote';
            newQuote.CONTAINER_Status__c = 'Pending VP Approval';
            //Additional
            newQuote.CONTAINER_Model_Number__c = null;
            newQuote.CONTAINER_Cost_Contract_Price__c = null;
            newQuote.CONTAINER_Payment_Terms__c = null;
            newQuote.CONTAINER_Payment_Terms_GENSET__c = null;
            newQuote.CONTAINER_Method_of_Shipment__c = null;
            newQuote.CONTAINER_Method_of_Shipment_GENSET__c = null;
            newQuote.CONTAINER_Freight_Terms__c = null;
            newQuote.CONTAINER_Freight_Terms_GENSET__c = null;
                
        	//Insert quote new record
            insert newQuote;
        
            Test.setCurrentPage(pageRef);
                pageRef.getParameters().put('Id',newQuote.id);
                ApexPages.StandardController sc = new ApexPages.StandardController(newQuote);
                QuoteExtController controller = new QuoteExtController(sc);
                controller.onSubmit();
        		//System.assertEquals(newQuote.,controller.autoRun());
        	Test.stopTest();
    }
    
    @isTest
    public static void onSubmitTestV2(){
        test.startTest();
            PageReference pageRef = Page.SubmitQuote;
        	CONTAINER_UtilityClass.createCustomerQuote();
        	//Query the Id and add it on the list.
        	Opportunity opp = [Select id, name from opportunity limit 1];
        
            id qteRecTypeID = Schema.SobjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('CONTAINER_NT_Quote').getRecordTypeId();
            SBQQ__Quote__c newQuote = new SBQQ__Quote__c();
            newQuote.RecordTypeId = qteRecTypeID;
            newQuote.SBQQ__Opportunity2__c = opp.Id;
            newQuote.CONTAINER_Sales_Region__c = 'APO';
        	newQuote.CONTAINER_Qty__c = 2;
        	//newQuote.CONTAINER_Type__c = 'End Customer Quote';
            newQuote.CONTAINER_Status__c = 'Pending VP Approval';
        	//Additional
            newQuote.CONTAINER_Model_Number__c = 'tt';
            newQuote.CONTAINER_Cost_Contract_Price__c = 23;
            newQuote.CONTAINER_Payment_Terms__c = '45 DAYS PAYMENT TERM - 45';
            newQuote.CONTAINER_Payment_Terms_GENSET__c = 'NET 30 DAYS - N30';
        	newQuote.CONTAINER_Method_of_Shipment__c = 'AIR FREIGHT - AF';
            newQuote.CONTAINER_Method_of_Shipment_GENSET__c = null;
        	newQuote.CONTAINER_Freight_Terms__c = 'DELIVERED DUTY PAID - DDP';
            //Insert quote new record
            insert newQuote;
        
            Test.setCurrentPage(pageRef);
                pageRef.getParameters().put('Id',newQuote.id);
                ApexPages.StandardController sc = new ApexPages.StandardController(newQuote);
                QuoteExtController controller = new QuoteExtController(sc);
                controller.onSubmit();
        		//System.assertEquals(newQuote.,controller.autoRun());
        	Test.stopTest();
    }
    
    @isTest
    public static void onSubmitWithStatusApprovedTest(){
        test.startTest();
            PageReference pageRef = Page.SubmitQuote;
        	CONTAINER_UtilityClass.createCustomerQuote();
        	//Query the Id and add it on the list.
        	Opportunity opp = [Select id, name from opportunity limit 1];
        
            id qteRecTypeID = Schema.SobjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('CONTAINER_NT_Quote').getRecordTypeId();
            SBQQ__Quote__c newQuote = new SBQQ__Quote__c();
            newQuote.RecordTypeId = qteRecTypeID;
            newQuote.SBQQ__Opportunity2__c = opp.Id;
            newQuote.CONTAINER_Sales_Region__c = 'APO';
            newQuote.ApprovalStatus__c = ContainerConstants.APPROVED_STATUS;//Status is approved
            //Insert quote new record
            insert newQuote;
        
            Test.setCurrentPage(pageRef);
                pageRef.getParameters().put('Id',newQuote.id);
                ApexPages.StandardController sc = new ApexPages.StandardController(newQuote);
                QuoteExtController controller = new QuoteExtController(sc);
                controller.onSubmit();
        		//System.assertEquals(newQuote.,controller.autoRun());
        	Test.stopTest();
    }
    
    @isTest
    public static void onSubmitWithStatusSubmittedTest(){
        test.startTest();
            PageReference pageRef = Page.SubmitQuote;
        	CONTAINER_UtilityClass.createCustomerQuote();
        	//Query the Id and add it on the list.
        	Opportunity opp = [Select id, name from opportunity limit 1];
        
            id qteRecTypeID = Schema.SobjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('CONTAINER_NT_Quote').getRecordTypeId();
            SBQQ__Quote__c newQuote = new SBQQ__Quote__c();
            newQuote.RecordTypeId = qteRecTypeID;
            newQuote.SBQQ__Opportunity2__c = opp.Id;
            newQuote.CONTAINER_Sales_Region__c = 'APO';
        	newQuote.CONTAINER_Payment_Terms__c = '45 DAYS PAYMENT TERM - 45';
        	newQuote.CONATINER_3rd_Party_Commission__c = 'test';
            newQuote.ApprovalStatus__c = ContainerConstants.SUBMITTED_STATUS;//Status is Pending
            //Insert quote new record
            insert newQuote;
        
            Test.setCurrentPage(pageRef);
                pageRef.getParameters().put('Id',newQuote.id);
                ApexPages.StandardController sc = new ApexPages.StandardController(newQuote);
                QuoteExtController controller = new QuoteExtController(sc);
                controller.onSubmit();
        		//System.assertEquals(newQuote.,controller.autoRun());
        	Test.stopTest();
    }
    
    @isTest
    public static void onRecallTest(){
        Profile prof = [SELECT Id FROM Profile WHERE Name='CONTAINER Administrator'];
        User newUser = new User(Alias = 'contAdm', Email='contAdmin@carrier.com', LastName='AdminTest', ProfileId = prof.Id, 
                                UserName='testAdminUser@carrier.com', EmailEncodingKey='UTF-8', 
                                LanguageLocaleKey='en_US', LocaleSidKey='en_US', TimeZoneSidKey='America/Los_Angeles');
        insert newUser;
        
        System.runAs(newUser) {
        test.startTest();
            PageReference pageRef = Page.SubmitQuote;
        	CONTAINER_UtilityClass.createCustomerQuote();
        	//Query the Id and add it on the list.
            List<SBQQ__Quote__c> quoteID = [select id from SBQQ__Quote__c where CONTAINER_ASO_ID__c ='3415'];
        
            Test.setCurrentPage(pageRef);
            pageRef.getParameters().put('Id',quoteID[0].id);
            ApexPages.StandardController sc = new ApexPages.StandardController(quoteID[0]);
            QuoteExtController controller = new QuoteExtController(sc);
        	controller.onRecall();
        	controller.onPreview();
        	controller.returnToQuote();
            //System.assertNotEquals(null,controller.autoRun());
        
        test.stopTest();
        }
    }
}