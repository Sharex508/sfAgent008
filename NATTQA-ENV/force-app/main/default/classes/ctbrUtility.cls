/*Author: LTI
* Created Date: 4th October 2022
* Class Name: ctbrUtility
* Description: This class is used to store common methods 
*/
public class ctbrUtility {
    public static void LogException(Exception ex,String ClassName,String MethodName) {
        
        Salesforce_API_Logs__c log = new Salesforce_API_Logs__c();
        log.CTBR_ClassName__c=ClassName; 
        log.CTBR_MethodName__c=MethodName; 
        log.CTBR_StackTrace__c=ex.getStackTraceString(); 
        log.CTBR_Exception_Type__c=ex.getTypeName();
        log.CTBR_Exception_Message__c=ex.getMessage(); 
        log.CTBR_Line_Number__c=ex.getLineNumber(); 
        
        insert log; 
    }
    
    
    //this method is used to log all api transaction from SAP
   /*
    public static void logAPI(HttpResponse response, String requestBody,Datetime requestTime) {
        
        Salesforce_API_Logs__c log = new Salesforce_API_Logs__c();
        log.CTBR_Request_From_Salesforce__c = requestBody;
        log.CTBR_Request_Time__c = requestTime;
        log.CTBR_Response_Time__c = System.now();
        
        if(response.getStatusCode() == 200){
            log.CTBR_Response_From_SAP__c = response.getBody();
        }else{
            log.CTBR_Response_From_SAP__c = 'API Callout Error with status code '+ response.getStatusCode()+' and Status '+ response.getStatus()+response.getBody(); 
        }
        
        insert log;
    }*/
    
}