public without sharing class nac_UserManagementController{   
    private List<String> contactIdSet;
    public nac_UserManagementController(List<Id> records) {
        this.contactIdSet = records;
        
    }

    @AuraEnabled
    public static sObjectWrapper fetchData(String fieldSetName, String sortFieldSetName, String objectName,String effectiveAccountId){
        sObjectWrapper sObjWrap = new sObjectWrapper();
        sObjWrap.field = getFields(fieldSetName, sortFieldSetName, objectName);
        system.debug('sObjWrap.field.hasError'+sObjWrap.field.hasError+' '+sObjWrap.field);
        if(sObjWrap.field.hasError){ 
            sObjWrap.hasError = true;
            sObjWrap.errorMessage = sObjWrap.field.errorMessage; 
        }else{
            try{
                String query = 'SELECT ';
                for(field f : sObjWrap.field.fieldList) {
                    if(f.type == 'datetime'){
                        query += 'FORMAT('+f.fieldName + '), ';
                    }else{
                        query += f.fieldName + ', ';
                    }
                }
                String filterStatus = 'Inactive';
                Id nacContactRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NAOCAP_End_Customer').getRecordTypeId();
                query += 'Id FROM ' + objectName + ' Where AccountId=\''+effectiveAccountId+'\' AND NAC_Status__c !='+'\''+ filterStatus+ '\'';
                query += ' AND RecordTypeId =: nacContactRecordTypeId';
                sObjWrap.sObjectList = Database.query(query);
            }catch(Exception e){
                sObjWrap.hasError = true;
                sObjWrap.errorMessage = e.getTypeName() + ' ' + e.getMessage() + ' ' + e.getStackTraceString();
                system.debug('exception ' + e.getTypeName());
                system.debug('exception ' + e.getMessage());
                system.debug('exception ' + e.getStackTraceString());
            }
        }
        return sObjWrap;
    } 
    
    @AuraEnabled
    public static fields getFields(String fieldSetName, String sortFieldSetName, String objectName) {
        fields field = new fields();
        try{
            Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
            Schema.DescribeSObjectResult objectDescribe = objectType.getDescribe();
            Map<String, Schema.FieldSet> fieldSetMap = objectDescribe.fieldSets.getMap();
            if(fieldSetMap.containsKey(fieldSetName)){
                List<String> sortFields = new List<String>();
                if(String.isNotBlank(sortFieldSetName) && fieldSetMap.containsKey(sortFieldSetName)){
                    for(Schema.FieldSetMember fsm : fieldSetMap.get(sortFieldSetName).getFields()){
                        sortFields.add(fsm.getFieldPath());
                    }
                }
                Schema.FieldSet fs = fieldSetMap.get(fieldSetName);
                for(Schema.FieldSetMember fsm : fs.getFields()){
                    field.fieldList.add(new field(fsm, sortFields));
                }
            }else{
                field.hasError = true;
                field.errorMessage = 'Did not find the field set named ' + fieldSetName + ' in the object ' + objectName;
            }
        }catch(Exception e){
            field.hasError = true;
            field.errorMessage = e.getTypeName() + ' ' + e.getMessage() + ' ' + e.getStackTraceString();
            system.debug('exception ' + e.getTypeName());
            system.debug('exception ' + e.getMessage());
            system.debug('exception ' + e.getStackTraceString());
        }
        return field;
    }

    @AuraEnabled
    public static Id getContactRt(){
        try {           
            return Schema.SobjectType.Contact.getRecordTypeInfosByDeveloperName().get('NATT_Dealer').getRecordTypeId();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean updateContactRecord(Map<String,String> contactRecord,String recordId) { 
        Boolean isUpdated= false;
        List<String> contactIdSetToUpdate = new List<String>();
        Contact conToUpdate = [Select Id,FirstName,LastName,Title,Email, Phone FROM Contact WHERE Id=:recordId Limit 1];
        try { 
              System.debug('contactRecord--->'+contactRecord);              
                conToUpdate.FirstName = String.valueOf(contactRecord.get('FirstName')) ;  
                conToUpdate.LastName = String.valueOf(contactRecord.get('LastName')) ;
                conToUpdate.Email = String.valueOf(contactRecord.get('Email')) ;
                conToUpdate.Title = String.valueOf(contactRecord.get('Title')) ;
                conToUpdate.Phone = String.valueOf(contactRecord.get('Phone'));            
                conToUpdate.NAC_Status__c ='Pending';               
            
            System.debug('conToUpdate--->'+conToUpdate);
            update conToUpdate;
            List<User> communityUser = [SELECT Id, FirstName, LastName, Email, Title, Phone FROM User WHERE ContactId =: recordId AND ProfileId IN (SELECT Id FROM Profile WHERE Name = 'NAC Customer Community Profile') LIMIT 1];
            if(!communityUser.isEmpty()){
                boolean isChanged =  false;
                if(communityUser[0].FirstName != conToUpdate.FirstName){
                    communityUser[0].FirstName = conToUpdate.FirstName;
                    isChanged =  true;
                }
                if(communityUser[0].LastName != conToUpdate.LastName){
                    communityUser[0].LastName = conToUpdate.LastName;
                    isChanged =  true;
                }
                if(communityUser[0].Email != conToUpdate.Email){
                    communityUser[0].Email = conToUpdate.Email;
                    isChanged =  true;
                }
                if(communityUser[0].Title != conToUpdate.Title){
                    communityUser[0].Title = conToUpdate.Title;
                    isChanged =  true;
                }
                if(communityUser[0].Phone != conToUpdate.Phone){
                    communityUser[0].Phone = conToUpdate.Phone;
                    isChanged =  true;
                }
                if(isChanged){
                    update communityUser;
                }
            }
            isUpdated = true;
            
            
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        return isUpdated;
    }

    @AuraEnabled
    public static Boolean deactivateContactRecord(String recordId) {
        Boolean isUpdated= false;
        try { 
            Contact con =[Select Id,NAC_status__c from Contact where Id=:recordId Limit 1];
            con.NAC_Status__c ='Inactive';
            update con;
            isUpdated=true;            
            List<User> userToUpdate=[Select Id,FirstName,LastName,Phone,Email,Title from User Where ContactId=:recordId];
           
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return isUpdated;
    }

    @AuraEnabled
    public static Boolean checkPartContactType() { 
        Boolean isParts=false;
        try { 
            User currUser=[Select Id, ContactId from User where Id=:UserInfo.getUserId()];
            System.debug('currUser--->'+currUser);
            if(currUser.ContactId !=null){
                Contact con =[Select Id,NAC_Contact_Type__c,NAC_Status__c from Contact where Id=:currUser.ContactId Limit 1];
                System.debug('con--->'+con);
                if(con !=null && con.NAC_Contact_Type__c=='Parts Ordering' && (con.NAC_Status__c =='Approved' ||con.NAC_Status__c =='Pending')){
                    isParts=true;
                }
            }
           
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return isParts;
    }
    

   


    
    public class sObjectWrapper{
        @AuraEnabled public List<sObject> sObjectList;
        @AuraEnabled public fields field;
        @AuraEnabled public boolean hasError;
        @AuraEnabled public string errorMessage;
        public sObjectWrapper(){
            sObjectList = new List<sObject>();
            hasError = false;
            errorMessage = '';
        }
    }
    
    public class fields{
        @AuraEnabled public boolean hasError;
        @AuraEnabled public string errorMessage;
        @AuraEnabled public List<field> fieldList;
        public fields(){
            hasError = false;
            errorMessage = '';
            fieldList = new List<field>();
        }
    }
    
    public class field{
        @AuraEnabled public string fieldName;
        @AuraEnabled public boolean isRequired;
        @AuraEnabled public string label;
        @AuraEnabled public string type;
        @AuraEnabled public boolean sortable;
        public field(Schema.FieldSetMember fsm, List<String> sortFields){
            fieldName = fsm.getFieldPath();
            label = fsm.getLabel();
            type = String.valueOf(fsm.getType()).toLowercase();
            if(fsm.getDbRequired() || fsm.getRequired()){
                isRequired = true;
            }else{
                isRequired = false;
            }
            if(sortFields.contains(fieldName)){
                sortable = true;
            }else{
                sortable = false;
            }
        }
    }

}