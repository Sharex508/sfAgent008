/*************************************************************************************************
Apex Class Name : ScheduleBatchAssignChatterGroupToUsrTest
Version : 1.0
Created Date : 12/04/2023
Function : This is the test class for ScheduleBatchAssignChatterGroupToUsers

Modification Log:
-------------------------------------------------------------------------------------------------------------------------------------------------
* Developer                                Date                                Description
* -----------------------------------------------------------------------------------------------------------------------------------------------
* Sanjay Sarraf         		     12/04/2023                        Initial creation        
*************************************************************************************************/

@IsTest
public class ScheduleBatchAssignChatterGroupToUsrTest {    
   
    @IsTest
    Public static void executeTest()
    {
        
        User sysAdmin = [SELECT Id,Name,Profile.Name FROM USER WHERE Profile.Name='System Administrator'and IsActive=true LIMIT 1]; 
        system.runAs(sysAdmin)
        {           
            
            Test.startTest();      
            List<String> lstCountrys = new List<String>();
            ScheduleBatchAssignChatterGroupToUsers schInst = new ScheduleBatchAssignChatterGroupToUsers();
            System.schedule('WeeklyBatch', '0 0 6 ? * MON', schInst);
            Test.stopTest();
        }
    }
}