/*************************************************************************************************
Apex Class Name : CoreReturnsCaseCloseEmailAlrtBchSchdTest
Version : 1.0
Created Date : 07/06/2023
Function : This is the test class for CoreReturnsCaseCloseEmailAlertBatchSched

Modification Log:
-------------------------------------------------------------------------------------------------------------------------------------------------
* Developer                                Date                                Description
* -----------------------------------------------------------------------------------------------------------------------------------------------
* Sanjay Sarraf         		     07/06/2023                        Initial creation        
*************************************************************************************************/

@IsTest
public class CoreReturnsCaseCloseEmailAlrtBchSchdTest {    
   
    @IsTest
    Public static void executeTest()
    {
        
        User sysAdmin = [SELECT Id,Name,Profile.Name FROM USER WHERE Profile.Name='System Administrator'and IsActive=true LIMIT 1]; 
        system.runAs(sysAdmin)
        {           
            
            Test.startTest();      
            CoreReturnsCaseCloseEmailAlertBatchSched schInst = new CoreReturnsCaseCloseEmailAlertBatchSched();
            System.schedule('WeeklyBatch', '0 0 6 ? * MON', schInst);
            Test.stopTest();
        }
    }
}