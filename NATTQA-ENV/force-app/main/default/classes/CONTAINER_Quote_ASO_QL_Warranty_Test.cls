@isTest
public class CONTAINER_Quote_ASO_QL_Warranty_Test {
    @testSetup 
    static void setup() {
        
        // This code runs as the system user
        Profile prof = [SELECT Id FROM Profile WHERE Name='CONTAINER Administrator'];
        User newUser = new User(Alias = 'contAdm', Email='contAdmin@carrier.com', LastName='AdminTest', ProfileId = prof.Id, 
                                UserName='testAdminUser@carrier.com', EmailEncodingKey='UTF-8', 
                                LanguageLocaleKey='en_US', LocaleSidKey='en_US', TimeZoneSidKey='America/Los_Angeles');
        insert newUser;       
        
    }
    @isTest
    public static void WarrantyTest1(){
        User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];
        CONTAINER_UtilityClass.createCustomerQuote();        
        
        Test.startTest();
        system.runAs(containerAdmin){
            List<SBQQ__Quote__c> quoteID = [SELECT Id from SBQQ__Quote__c where CONTAINER_ASO_ID__c ='3415'];
            List<SBQQ__QuoteLine__c> qtLine = [SELECT Id, NATT_P_N__c, SBQQ__Quote__c, SBQQ__Product__c from SBQQ__QuoteLine__c where SBQQ__Quote__c =: quoteID[0].Id];
            List<Product2> productId = [SELECT Id, productCode from Product2 where productCode ='SJ PD 1'];
            
            SBQQ__ProductFeature__c objPF = new SBQQ__ProductFeature__c();
            objPF.Name = 'Test Feature';
            objPF.SBQQ__ConfiguredSKU__c = productId[0].Id;
            objPF.SBQQ__Number__c = 2;
            objPF.SBQQ__MinOptionCount__c = 1;
            objPF.SBQQ__Category__c = 'Warranty';
            insert objPF;
            
            SBQQ__ProductOption__c objPopt = new SBQQ__ProductOption__c();
            objPopt.SBQQ__Number__c = 2;
            objPopt.SBQQ__ConfiguredSKU__c = productId[0].Id;
            objPopt.SBQQ__Feature__c = objPF.Id;
            objPopt.SBQQ__OptionalSKU__c = productId[0].Id;
            insert objPopt;        
            
            qtLine[0].SBQQ__ProductOption__c = objPopt.Id;
            update qtLine[0];
            
            ContainerQuote_ASO_QL_Warranty objASOQL = new ContainerQuote_ASO_QL_Warranty();
            objASOQL.quoteId = quoteID[0].Id;
            objASOQL.getwarrantyRecords();
            
            system.assert(quoteID.size()>0 , 'Checking Quote Size');
            Test.stopTest();
        }
        
    }
    
    @isTest
    public static void WarrantyTest2(){
        User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];
        CONTAINER_UtilityClass.createCustomerQuote();
        Test.startTest();
        system.runAs(containerAdmin){
            List<SBQQ__Quote__c> quoteID = [select Id from SBQQ__Quote__c where CONTAINER_ASO_ID__c ='3415'];
            ContainerQuote_ASO_QL_Warranty objASOQL = new ContainerQuote_ASO_QL_Warranty();
            objASOQL.getwarrantyRecords();
            
            objASOQL.quoteId = quoteID[0].Id;
            objASOQL.getwarrantyRecords();
            
            
            system.assert(quoteID.size()>0 , 'Checking Quote Size');
            Test.stopTest();
        }
    }
}