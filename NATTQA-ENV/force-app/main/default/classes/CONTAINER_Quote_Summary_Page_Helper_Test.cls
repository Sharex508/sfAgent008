@isTest
public class CONTAINER_Quote_Summary_Page_Helper_Test {
    
    @testsetup
    static void testName()
    {
        Test.startTest();
        //creating account record-
        id accRecTypeID = Schema.SobjectType.Account.getRecordTypeInfosByDeveloperName().get('CONTAINER_Customer').getRecordTypeId();
        Account acc = new Account();
        acc.Name = 'Test Acc1'; 
        acc.RecordTypeId = accRecTypeID;
        insert acc;
        
        //creating product record-
        Product2 p = new Product2();
        p.Name = ' Test Product ';
        p.Description='Test Product Entry For Product';
        p.productCode = 'SJ PD 1';
        p.isActive = true;
        insert p;
        
        // insert pricebook entry for the product
        Id pricebookId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(Product2Id = p.Id,
                                         pricebook2Id = pricebookId,
                                         unitprice=100, isActive=true);
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
        
        //creating quote record-
        id qteRecTypeID = Schema.SobjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('CONTAINER_GENSET_Quote').getRecordTypeId();
        SBQQ__Quote__c qteRec = new SBQQ__Quote__c();
        qteRec.CONTAINER_Sales_Region__c = 'EMEA';
        qteRec.RecordTypeId = qteRecTypeID;
        qteRec.SBQQ__Opportunity2__c = opp.Id;
        qteRec.CONTAINER_Model_Number__c = '69NT40-489-114';
        insert qteRec;

        //Creating User
        String uniqueUserName = 'ctsalesuser' + DateTime.now().getTime() + '@testorg.com';
        // This code runs as the system user
        Profile prof = [SELECT Id FROM Profile WHERE Name='CONTAINER Sales'];
        User u = new User(Alias = 'ctSales', Email='salesuser@testorg.com',
                            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                            LocaleSidKey='en_US', ProfileId = prof.Id,TimeZoneSidKey='America/Los_Angeles',
                            UserName=uniqueUserName);
        insert u;

        Test.stopTest();
    }

    @isTest
    public static void test1(){
        
        SBQQ__QuoteLine__c qtLine = new SBQQ__QuoteLine__c();
        qtLine.SBQQ__Bundle__c = true;
        qtLine.NATT_P_N__c = 'SPARE PARTS';
        qtLine.SBQQ__Quote__c = [select id from SBQQ__Quote__c limit 1].Id;
        qtLine.SBQQ__Product__c = [select id from Product2 limit 1].Id;
        insert qtLine;
        
        List<CONTAINER_Quote_Summary_Page_Helper.DataWrapper> result = new List<CONTAINER_Quote_Summary_Page_Helper.DataWrapper>();
        System.runAs(new User(Id = Userinfo.getUserId())) {
            result = CONTAINER_Quote_Summary_Page_Helper.getQuoteSummary(qtLine.SBQQ__Quote__c);
        }
        system.assert(result.size()>0 , 'Checking result is not Null');
    }

    @isTest
    public static void test2(){
        
        //creating quoteline items records-
        SBQQ__QuoteLine__c qtLine = new SBQQ__QuoteLine__c();
        qtLine.NATT_P_N__c = 'Extended Warranty Bundle';
        qtLine.SBQQ__Quote__c = [select id from SBQQ__Quote__c limit 1].Id;
        qtLine.SBQQ__Product__c = [select id from Product2 limit 1].Id;
        insert qtLine;
        
        List<CONTAINER_Quote_Summary_Page_Helper.DataWrapper> result = new List<CONTAINER_Quote_Summary_Page_Helper.DataWrapper>();
        System.runAs(new User(Id = Userinfo.getUserId())) {
            result = CONTAINER_Quote_Summary_Page_Helper.getQuoteSummary(qtLine.SBQQ__Quote__c);
        }
        system.assert(result.size()>0 , 'Checking result is not Null');
    }
    
    @isTest
    public static void test3(){
        
        //creating product record-
        Product2 p = new Product2();
        p.Name = ' Test Product ';
        p.Description='Test Product Entry For Product';
        p.productCode = 'Reserves Applied Sales';
        p.isActive = true;
        insert p;
        
        //creating quoteline items records-
        SBQQ__QuoteLine__c qtLine = new SBQQ__QuoteLine__c();
        qtLine.SBQQ__Quote__c = [select id from SBQQ__Quote__c limit 1].Id;
        qtLine.SBQQ__Product__c = p.Id;
        insert qtLine;
        
        List<CONTAINER_Quote_Summary_Page_Helper.DataWrapper> result = new List<CONTAINER_Quote_Summary_Page_Helper.DataWrapper>();
        System.runAs(new User(Id = Userinfo.getUserId())) {
            result = CONTAINER_Quote_Summary_Page_Helper.getQuoteSummary(qtLine.SBQQ__Quote__c);
        }
        system.assert(result.size()>0 , 'Checking result is not Null');
    }
    
    @isTest
    public static void test3Method1(){
        
        //creating product record-
        Product2 p = new Product2();
        p.Name = ' Test Product ';
        p.Description='Test Product Entry For Product';
        p.productCode = 'Reserves Applied Sales';
        p.isActive = true;
        insert p;
        
        //creating quoteline items records-
        SBQQ__QuoteLine__c qtLine = new SBQQ__QuoteLine__c();
        qtLine.SBQQ__Quote__c = [select id from SBQQ__Quote__c limit 1].Id;
        qtLine.SBQQ__Product__c = p.Id;
        qtLine.CONTAINER_Warranty_Description__c = 'Test';
        insert qtLine;
        
        List<CONTAINER_Quote_Summary_Page_Helper.DataWrapper> result = new List<CONTAINER_Quote_Summary_Page_Helper.DataWrapper>();
        System.runAs(new User(Id = Userinfo.getUserId())) {
            result = CONTAINER_Quote_Summary_Page_Helper.getQuoteSummary(qtLine.SBQQ__Quote__c);
        }
        system.assert(result.size()>0 , 'Checking result is not Null');
    }
    
    @isTest
    public static void test4(){
        
        //creating product record-
        Product2 p = new Product2();
        p.Name = ' Test Product ';
        p.Description='Test Product Entry For Product';
        p.productCode = 'Reserves Applied Cost';
        p.isActive = true;
        insert p;
        
        //creating quoteline items records-
        SBQQ__QuoteLine__c qtLine = new SBQQ__QuoteLine__c();
        qtLine.SBQQ__Quote__c = [select id from SBQQ__Quote__c limit 1].Id;
        qtLine.SBQQ__Product__c = p.Id;
        insert qtLine;
        
        List<CONTAINER_Quote_Summary_Page_Helper.DataWrapper> result = new List<CONTAINER_Quote_Summary_Page_Helper.DataWrapper>();
        System.runAs(new User(Id = Userinfo.getUserId())) {
            result = CONTAINER_Quote_Summary_Page_Helper.getQuoteSummary(qtLine.SBQQ__Quote__c);
        }
        system.assert(result.size()>0 , 'Checking result is not Null');
    }
    
    @isTest
    public static void test4Method1(){
        
        //creating product record-
        Product2 p = new Product2();
        p.Name = ' Test Product ';
        p.Description='Test Product Entry For Product';
        p.productCode = 'Reserves Applied Cost';
        p.isActive = true;
        insert p;
        
        //creating quoteline items records-
        SBQQ__QuoteLine__c qtLine = new SBQQ__QuoteLine__c();
        qtLine.SBQQ__Quote__c = [select id from SBQQ__Quote__c limit 1].Id;
        qtLine.SBQQ__Product__c = p.Id;
        qtLine.CONTAINER_Warranty_Description__c = 'Test';
        insert qtLine;
        
        List<CONTAINER_Quote_Summary_Page_Helper.DataWrapper> result = new List<CONTAINER_Quote_Summary_Page_Helper.DataWrapper>();
        System.runAs(new User(Id = Userinfo.getUserId())) {
            result = CONTAINER_Quote_Summary_Page_Helper.getQuoteSummary(qtLine.SBQQ__Quote__c);
        }
        system.assert(result.size()>0 , 'Checking result is not Null');
    }
}