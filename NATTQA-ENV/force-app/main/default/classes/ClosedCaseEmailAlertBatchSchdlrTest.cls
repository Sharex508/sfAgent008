/*************************************************************************************************
Apex Class Name : ClosedCaseEmailAlertBatchSchdlrTest
Version : 1.0
Created Date : 11/05/2023
Function : This is the test class for ClosedCaseEmailAlertBatchScheduler

Modification Log:
-------------------------------------------------------------------------------------------------------------------------------------------------
* Developer                                Date                                Description
* -----------------------------------------------------------------------------------------------------------------------------------------------
* Sanjay Sarraf         		     11/05/2023                        Initial creation        
*************************************************************************************************/

@IsTest
public class ClosedCaseEmailAlertBatchSchdlrTest {    
   
    @IsTest
    Public static void executeTest()
    {
        
        User sysAdmin = [SELECT Id,Name,Profile.Name FROM USER WHERE Profile.Name='System Administrator'and IsActive=true LIMIT 1]; 
        system.runAs(sysAdmin)
        {           
            
            Test.startTest();      
            ClosedCaseEmailAlertBatchScheduler schInst = new ClosedCaseEmailAlertBatchScheduler();
            System.schedule('WeeklyBatch', '0 0 6 ? * MON', schInst);
            Test.stopTest();
        }
    }
}