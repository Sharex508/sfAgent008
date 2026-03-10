@isTest public class CONTAINER_TriggerHandler_Test {
	@isTest static void testafterInsert(){
        CONTAINER_UtilityClass.createCustomerQuoteBulk_NT();  
        CONTAINER_TriggerHandler obj = new CONTAINER_TriggerHandler();
        obj.setMaxLoopCount(100);
        obj.clearMaxLoopCount();
        CONTAINER_TriggerHandler.bypass('ContainerQuoteTrigger');
        CONTAINER_TriggerHandler.clearBypass('ContainerQuoteTrigger');
        CONTAINER_TriggerHandler.isBypassed('ContainerQuoteTrigger');
        CONTAINER_TriggerHandler.clearAllBypasses();
        
    }
    public static testMethod void testRunAs() {
        /// This code runs as the system user
        Profile prof = [SELECT Id FROM Profile WHERE Name='CONTAINER Administrator'];
        User newUser = new User(Alias = 'contAdm', Email='contAdmin@carrier.com', LastName='AdminTest', ProfileId = prof.Id, 
                                UserName='testAdminUser@carrier.com', EmailEncodingKey='UTF-8', 
                                LanguageLocaleKey='en_US', LocaleSidKey='en_US', TimeZoneSidKey='America/Los_Angeles');
        insert newUser;
        
        System.runAs(newUser) {
            try{    
                
                CONTAINER_UtilityClass.createCustomerQuote();
                List<CONTAINER_Control_Trigger_And_Validation__mdt> eachMD = [SELECT DeveloperName, CONTAINER_Skip_Trigger_Flag__c, CONTAINER_Trigger_Class_Name__c FROM CONTAINER_Control_Trigger_And_Validation__mdt WHERE CONTAINER_Skip_Trigger_Flag__c = TRUE];
                List<SBQQ__Quote__c> quoteID = [select Id from SBQQ__Quote__c where CONTAINER_ASO_ID__c ='3415'];
                quoteID[0].CONTAINER_Sales_Region__c=ContainerConstants.NAO;
                update quoteID[0];
                delete quoteID;
                List<SBQQ__Quote__c> undeletequoteID = [select Id from SBQQ__Quote__c where CONTAINER_ASO_ID__c ='3415' ALL ROWS];
                undelete undeletequoteID;
            }
            catch(Exception e){
                Boolean expectedExceptionThrown =  (e.getMessage().contains('You do not have permissions to delete the record:')) ? true : false;
               
            }
        }
    }
}