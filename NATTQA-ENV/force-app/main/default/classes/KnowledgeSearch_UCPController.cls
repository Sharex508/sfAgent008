/********************************************************************************************************
* @author         (Deloitte)
* @description    This is a apex class for knowledge Search component created specific for REF Dealer users.
* @date           03/29/2023 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Deloitte               03/29/2023                                  Initial version
*********************************************************************************************************/

public without sharing class KnowledgeSearch_UCPController {
    
    /*Get Department, Segment and DocType picklist values on component load
*return wrapper class lists to the component*/
    @AuraEnabled
    public static WrapPicklist getPickList() {
        //list<string> deplist = new list<string>();
        list<string> seglist = new list<string>();
        list<string> doctypelist = new list<string>();
         
        //get picklist value from Knowledge object and sent it back to knowledge search component
        Map<String,Schema.SObjectType> allObj = Schema.getGlobalDescribe();
        Map<String,Schema.SObjectField> allFlds = allObj.get('Knowledge__kav').getDescribe().fields.getMap();
       /* List<Schema.PicklistEntry> departmentList = allFlds.get('NATT_Department__c').getDescribe().getPickListValues();
        for(Schema.PicklistEntry dpList : departmentList){
            deplist.add(dpList.getValue());
        }*/
        
        List<Schema.PicklistEntry> segmentList = allFlds.get('UCP_Segment__c').getDescribe().getPickListValues();
        for(Schema.PicklistEntry sgList : segmentList){
            seglist.add(sgList.getValue());
        }
        
        List<Schema.PicklistEntry> dctypeList = allFlds.get('NATT_Document_Type__c').getDescribe().getPickListValues();
        for(Schema.PicklistEntry dcList : dctypeList){
            doctypelist.add(dcList.getValue());
        }
        
        //Initilization and mapping the data for wrapper class
        WrapPicklist wrapknowledgePicklist = new WrapPicklist();
        //wrapknowledgePicklist.department = deplist;
        wrapknowledgePicklist.segment = seglist;
        wrapknowledgePicklist.documentType = doctypelist;
        return wrapknowledgePicklist;
    }
    
    //Wrapper class to get the picklist fields on component load 
    public class WrapPicklist {
       /* @AuraEnabled
        public list<string> department {get; set;}*/
        @AuraEnabled
        public list<string> segment {get; set;}
        @AuraEnabled
        public list<string> documentType {get; set;}
        
    }
    
    //Search for published knowledge articles based on User input.
    @AuraEnabled
    public static list<Knowledge__kav> getArticleList(string userinput,string title,string docNumber,string segment, string docType){
        Knowledge__kav [] knows;
        try {
            system.debug(segment);
            User objUser = [SELECT Id,Name,UCP_Region__c FROM User WHERE Id =:UserInfo.getUserId()];
            //query string for the knowledge search
            String query = 'SELECT Id, Title, NATT_Doc_Number__c, NATT_Department__c, UCP_Segment__c, NATT_Document_Type__c,LastModifiedDate FROM Knowledge__kav';
            String publishStatus = 'online';
			String whereClause = 'PublishStatus = \'online\' AND RecordType.Name = \'UCP Container\' AND (UCP_Region__c	 = \'UCP (Global)\' OR UCP_Region__c	 = \'' + objUser.UCP_Region__c + '\')';

            system.debug('whereClause'+whereClause);
            system.debug(String.isNotBlank(userinput));
            system.debug(String.isBlank(userinput));
            //User input null and soql injection check
            if(String.isNotBlank(userinput)){ 
                userinput = String.escapeSingleQuotes(userinput);
                //string queryInput = '*' +userinput+ '*';
                
                whereClause = getWhereClause(whereClause, Title, docNumber, segment, docType);
                
                String searchquery='FIND \'' + userinput +'\' IN ALL FIELDS RETURNING Knowledge__kav(Id, Title, NATT_Doc_Number__c, UCP_Segment__c, NATT_Document_Type__c,LastModifiedDate where ';
                String whereQueActual = '\'' +whereClause+'\'';
                String removeSingleQuotes = whereQueActual.substring(1, whereQueActual.length() - 1);
                //String result2 = result.substring(0, result.length() - 1);
                string finalQueryString = searchquery + removeSingleQuotes + ' Order by LastModifiedDate desc)';
                
                //query the list of Article search result
                List<List<SObject>> searchList =  search.query(finalQueryString);
                knows = ((List<Knowledge__kav>)searchList[0]);
                
            }
            else if(String.isBlank(userinput)){
                system.debug('whereClause isndesss');
                whereClause = getWhereClause(whereClause, Title, docNumber, segment, docType);
                //query the list of Article search result
                knows = Database.query(query +' where '+ whereClause);
                system.debug('where'+whereClause);
                system.debug('query'+query); 
                system.debug(knows);
            }
            
           
        }catch (Exception e) {
            //throw new AuraHandledException(e.getMessage());
        }
        return knows;
    }
    
    @AuraEnabled
    public static string getWhereClause(string whereClause, string title, string docNumber, string segment, string docType){
        if(String.isNotBlank(title)){
            title = String.escapeSingleQuotes(title);
            title = title.replace('*', '%');
            whereClause = whereClause + 'and Title like\'' + title +'\''; 
        }
        if(String.isNotBlank(docNumber)){
            docNumber = String.escapeSingleQuotes(docNumber);
            docNumber = docNumber.replace('*', '%');
            whereClause = whereClause + ' and NATT_Doc_Number__c like\'' + docNumber +'\'';
        }
        /*if(String.isNotBlank(department)){
            department = String.escapeSingleQuotes(department);
            whereClause = whereClause + ' and NATT_Department__c =:department';
        }*/
        if(String.isNotBlank(segment)){
            segment = String.escapeSingleQuotes(segment);
            whereClause = whereClause + ' and UCP_Segment__c =:segment'; 
        }
        if(String.isNotBlank(docType)){
            docType = String.escapeSingleQuotes(docType);
            whereClause = whereClause + ' and NATT_Document_Type__c =:docType'; 
        }
        
        Return whereClause;
    }
    
}