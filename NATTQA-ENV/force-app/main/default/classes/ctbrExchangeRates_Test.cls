@isTest(seeAllData = true)
public class ctbrExchangeRates_Test {
	public static Exchange_Rate__c exchangeRate1;
    public static Exchange_Rate__c exchangeRate2;
    
    static testMethod void exchangeTest() {
        
        exchangeRate1 = new Exchange_Rate__c();
        exchangeRate1.CTBR_Current_Rate__c = 2.5;
        exchangeRate1.CTBR_Previous_Rate__c = 2.0;
        exchangeRate1.Name = 'CTBR BlueEdge';
        insert exchangeRate1;
        
        exchangeRate1.CTBR_Current_Rate__c = 3.0;
        update exchangeRate1;
    }
    
    @IsTest
    static void testMyCallback() {
       
        // Instantiate the callback.
        Metadata.DeployCallback callback = new ctbrCustomMetadataCallback();     
        // Create test result and context objects.
        Metadata.DeployResult result = new Metadata.DeployResult();
        result.status = Metadata.DeployStatus.Succeeded;
        Metadata.DeployMessage messageObj = new Metadata.DeployMessage();
        messageObj.changed = true;
        messageObj.success = true;
        messageObj.fullName='';
        messageObj.componentType ='CustomMetadata';
        messageObj.fullName = 'VAT_Rate.SreeVardhan3';
        Metadata.DeployDetails deployDetailsObj = new Metadata.DeployDetails();
        deployDetailsObj.componentSuccesses.add(messageObj);
        result.details = deployDetailsObj;     
        Metadata.DeployCallbackContext context = new Metadata.DeployCallbackContext();
       
        // Invoke the callback's handleResult method.
        callback.handleResult(result, context);
    }
    
    @IsTest
    static void testMyCallbackErrorMessage() {
       
        // Instantiate the callback.
        Metadata.DeployCallback callback = new ctbrCustomMetadataCallback();     
         // Create test result and context objects.
        Metadata.DeployResult result = new Metadata.DeployResult();
        result.status = Metadata.DeployStatus.Failed;
        Metadata.DeployMessage messageObj = new Metadata.DeployMessage();
        messageObj.changed = false;
        messageObj.success = false;   
        messageObj.componentType ='CustomMetadata';
        messageObj.fullName = 'VAT_Rate.SreeVardhan3';
        messageOBj.problem = 'Default: value not of required type: 1';
        messageObj.problemType = Metadata.DeployProblemType.Error;


        Metadata.DeployDetails deployDetailsObj = new Metadata.DeployDetails();
        deployDetailsObj.componentFailures.add(messageObj);
        result.details = deployDetailsObj;     
        Metadata.DeployCallbackContext context = new Metadata.DeployCallbackContext();       
        // Invoke the callback's handleResult method.
        callback.handleResult(result, context);
    }
}