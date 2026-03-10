/********************************************************************************************************
* @author         Deloitte
* @description    Test class for ContainerQuoteASOTentativeRecords class.
* @date           09/02/2022 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Deloitte               09/02/2022                                   Initial version
*********************************************************************************************************/
@isTest
public class ContainerQuoteASOTentativeRecordsTest {

    @isTest
    public static void positiveTest1(){
        test.startTest();
            PageReference pageRef = Page.ContainerQuoteASOTentativeRecords;
        	CONTAINER_UtilityClass.createCustomerQuote();
        	//Query the Id and add it on the list.
            List<SBQQ__Quote__c> quoteID = [select id from SBQQ__Quote__c where CONTAINER_ASO_ID__c ='3415'];
        	CONTAINER_Tentative_Production_Schedule__c tps = new CONTAINER_Tentative_Production_Schedule__c();
        	tps.CONTAINER_TentativeProductionSchd_Qty__c = 2;
        	tps.CONTAINER_Week_Of__c = system.today();
        	tps.CONTAINER_Factory__c = 'ATHENS';
        	tps.CONTAINER_Quote_Number__c = quoteID[0].id;
        	insert tps;
        
                /// This code runs as the system user
        Profile prof = [SELECT Id FROM Profile WHERE Name='CONTAINER Administrator'];
        User newUser = new User(Alias = 'contAdm', Email='contAdmin@carrier.com', LastName='AdminTest', ProfileId = prof.Id, 
                                UserName='testAdminUser@carrier.com', EmailEncodingKey='UTF-8', 
                                LanguageLocaleKey='en_US', LocaleSidKey='en_US', TimeZoneSidKey='America/Los_Angeles');
        insert newUser;
        
        System.runAs(newUser) {
            try{ 
        
            Test.setCurrentPage(pageRef);
            pageRef.getParameters().put('qid',quoteID[0].id);
            ContainerQuoteASOTentativeRecords  controller = new ContainerQuoteASOTentativeRecords();
            //System.assertNotEquals(null,controller.autoRun());
            }
            catch(Exception e){
                Boolean expectedExceptionThrown =  (e.getMessage().contains('You do not have permissions to delete the record:')) ? true : false;
               
            }
        }
        test.stopTest();
    }
}