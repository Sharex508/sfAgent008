public class NATT_LookupController {
    
    @AuraEnabled
    public static List < sObject > fetchLookUpValues(String searchKeyword,String recordId,String ObjectName) {
        String searchKey = '%'+ searchKeyword + '%';
        
        List<sObject> returnList = new List<sObject>();
      
        // Create a Dynamic SOQL Query For Fetch Record List with LIMIT 5   
        String sQuery =  'select Id,OrderNumber,NATT_JDE_Sales_Order_Number__c,NATT_Unit__c From ' +ObjectName + ' Where SBQQ__Contracted__c = true AND AccountId = \''+String.escapeSingleQuotes(recordId)+'\' AND Type = \''+String.escapeSingleQuotes('New')+'\' AND NATT_Quote_Record_Type__c = \''+String.escapeSingleQuotes('NATT_Units_Quote')+'\' AND RecordType.DeveloperName = \''+String.escapeSingleQuotes('NATT_Units_Order')+'\' AND NATT_JDE_Sales_Order_Number__c LIKE :searchKey order by createdDate DESC limit 5';
        List<sObject> lstOfRecords = Database.query(sQuery);
        
        for(sObject obj: lstOfRecords) {
            returnList.add(obj);
        }
        return returnList;
    }
}