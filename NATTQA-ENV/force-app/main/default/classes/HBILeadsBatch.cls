/*
@name: HBILeadsBatch
@description: This Batch is used to update HBI Lead Status based on Source Lead
@date: 08 Aug 2020
@author: LTI
@changes:
*/
global class HBILeadsBatch implements Database.Batchable<sObject>,Database.Stateful,Database.AllowsCallouts {
    private String whereClause;
    global HBILeadsBatch(){
        whereClause = '';
    }
    global HBILeadsBatch(String whereClauseString){
        whereClause = whereClauseString;
    }
    
    /*
    @name: start
    @description: This method returns Lead records to be processed
    @date: 11 Aug 2020
    @author: LTI
    @changes:
    */
    global Database.Querylocator start (Database.BatchableContext BC) {
        String query;
        String filter = '(\'New\',\'Customer Contacted\',\'Qualified\',\'Accepted\',\'Rejected\',\'\')';
         if(whereClause.length() > 0){
            query = 'SELECT Id, HBI_Lead_Status__c, Record_Reference_Id__c, Receiving_Business__c FROM Lead'+whereClause;
        }else{
            query = 'SELECT Id, HBI_Lead_Status__c, Record_Reference_Id__c, Receiving_Business__c FROM Lead WHERE HBI_Lead_Status__c IN '+filter;
        } 
        return Database.getQueryLocator(query);
    }
    
    /*
    @name: execute
    @description: This method updates lead records in chunks
    @date: 11 Aug 2020
    @author: LTI
    @changes:
    */
    global void execute (Database.BatchableContext BC, List<Lead> scope) {
        List<Lead> leads = (List<Lead>) scope;
        LeadController.processDataFromAllOrgs(leads);
    }
    
    /*
    @name: execute
    @description: finish method
    @date: 11 Aug 2020
    @author: LTI
    @changes:
    */
    global void finish(Database.BatchableContext BC){  
    }
    
}