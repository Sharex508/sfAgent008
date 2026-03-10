public without sharing class NAC_CreateCaseController {
    
    @AuraEnabled
    public static caseWrapper getCaseDetails(String objectName) {
        caseWrapper caseWrap = new caseWrapper();
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
        Schema.DescribeSObjectResult objectDescribe = objectType.getDescribe();
        Map<String, Schema.FieldSet> fieldSetMap = objectDescribe.fieldSets.getMap();
        for(String fieldSetName : fieldSetMap.keySet()){
            if(fieldSetName.toUppercase().contains('NAC_CORE_RETURN') || fieldSetName.toUppercase().contains('NAC_PERFORMANCE')){
                sections section = new sections();
                section.sectionLabel = fieldSetMap.get(fieldSetName).getLabel();
                section.sectionAPIName = fieldSetName;
                if(section.sectionLabel.contains('_')){
                    List<string> splitStr = section.sectionLabel.split('_',2);
                    if(splitStr[0].isNumeric()){
                        section.order = integer.valueof(splitStr[0]);
                        section.sectionLabel = splitStr[1];
                    }
                }
                for(Schema.FieldSetMember fsm : fieldSetMap.get(fieldSetName).getFields()){
                    section.fieldList.add(new field(fsm));
                }
                if(!section.fieldList.isEmpty()){
                    if(fieldSetName.toUppercase().contains('NAC_CORE_RETURN')){
                        caseWrap.coreFields.add(section);
                    }else if(fieldSetName.toUppercase().contains('NAC_PERFORMANCE')){
                        caseWrap.performancePartsFields.add(section);
                    }
                }
            }
        }
        caseWrap.addressList = [SELECT Id, Street, City, State, PostalCode, Country, IsDefault, NATT_Address__c, NATT_Address__r.Id, AddressType FROM ContactPointAddress WHERE Recordtype.Name='NAC' AND ParentId IN (SELECT AccountId FROM User WHERE Id =: UserInfo.getUserId()) AND Status__c = 'Approved'];
        return caseWrap;
    }

    @AuraEnabled
    public static resultWrapper createCoreReturns(Map<String,String> caseField, List<Map<String,String>> returnItemFields) {
        resultWrapper rWrap = new resultWrapper();
        Savepoint sp;
        sp = Database.setSavepoint();
        try{
            case coreRetunCase = new case();
            //Before saving case, get the core return location and stamp lookup field for return location
            Id coreLocationLookup = [SELECT id FROM NATT_Core_Return_Location__c WHERE Core_Return_Location__c =: caseField.get('NATT_Core_Return_Location__c') LIMIT 1]?.Id;
            if(coreLocationLookup != null){
                coreRetunCase.put('NATT_Core_Return_Location_Account__c',coreLocationLookup);
            }
            for(String field : caseField.keySet()){
                if(field == 'NATT_Date_of_Entry__c'){
                    //coreRetunCase.put(field,caseField.get(field));
                }else{
                    coreRetunCase.put(field,caseField.get(field));
                }
            }
            insert coreRetunCase;
            List<NATT_Return_Item__c> returnItemList = new List<NATT_Return_Item__c>();
            for(Map<String,String> returnItemMap : returnItemFields){
                NATT_Return_Item__c returnItem = new NATT_Return_Item__c();
                for(String field : returnItemMap.keySet()){
                    if(field == 'NATT_Quantity__c'){
                        returnItem.put(field,decimal.valueOf(returnItemMap.get(field)));
                    }else{
                        returnItem.put(field,returnItemMap.get(field));
                    }
                }
                returnItem.NATT_Case__c = coreRetunCase.Id;
                returnItemList.add(returnItem);
            }
            insert returnItemList;
            rWrap.caseId = coreRetunCase.Id;            
        }catch(Exception e){
            Database.rollback(sp);
            rWrap.hasError = true;
            rWrap.errorMessage = e.getTypeName() + ' ' + e.getMessage() + ' ' + e.getStackTraceString();
            system.debug('exception ' + e.getTypeName());
            system.debug('exception ' + e.getMessage());
            system.debug('exception ' + e.getStackTraceString());
        }
        
        return rWrap;
    }

    @AuraEnabled
    public static resultWrapper createPerfPartReturns(Map<String,String> caseField, List<Map<String,String>> returnItemFields) {
        resultWrapper rWrap = new resultWrapper();
        Savepoint sp;
        sp = Database.setSavepoint();
        try{
            Case corePerfPartCase = new Case();
            for(String field : caseField.keySet()){       
                corePerfPartCase.put(field,caseField.get(field));                
            }           
            insert corePerfPartCase;
            List<NATT_Case_Sales_Order__c> returnItemList = new List<NATT_Case_Sales_Order__c>();
            for(Map<String,String> returnItemMap : returnItemFields){
                NATT_Case_Sales_Order__c returnItem = new NATT_Case_Sales_Order__c();
                for(String field : returnItemMap.keySet()){  
                    if(field == 'NATT_Disputed_Quantity__c'){
                        returnItem.put(field,decimal.valueOf(returnItemMap.get(field)));
                    }else{
                        returnItem.put(field,returnItemMap.get(field));                    
                    }                 
                }
                returnItem.NATT_Case__c = corePerfPartCase.Id;
                returnItemList.add(returnItem);
            }
            insert returnItemList;
            rWrap.caseId = corePerfPartCase.Id;
        
        }catch(Exception e){
            Database.rollback(sp);
            rWrap.hasError = true;
            rWrap.errorMessage = e.getTypeName() + ' ' + e.getMessage() + ' ' + e.getStackTraceString();
            system.debug('exception ' + e.getTypeName());
            system.debug('exception ' + e.getMessage());
            system.debug('exception ' + e.getStackTraceString());
        }
        return rWrap;
    }

    @AuraEnabled
    public static resultWrapper createPerfPartReturnInternal(Map<String,String> caseField, List<Map<String,String>> returnItemFields,String caseId) {
        resultWrapper rWrap = new resultWrapper();
        Savepoint sp;
        sp = Database.setSavepoint();
        try{
            List<NATT_Case_Sales_Order__c> returnItemList = new List<NATT_Case_Sales_Order__c>();
            for(Map<String,String> returnItemMap : returnItemFields){
                NATT_Case_Sales_Order__c returnItem = new NATT_Case_Sales_Order__c();
                for(String field : returnItemMap.keySet()){  
                    if(field == 'NATT_Disputed_Quantity__c'){
                        returnItem.put(field,decimal.valueOf(returnItemMap.get(field)));
                    }else{
                        returnItem.put(field,returnItemMap.get(field));                    
                    }                 
                }
                returnItem.NATT_Case__c = caseId;
                returnItemList.add(returnItem);
            }
            insert returnItemList;
            rWrap.caseId = caseId;
        
        }catch(Exception e){
            Database.rollback(sp);
            rWrap.hasError = true;
            rWrap.errorMessage = e.getTypeName() + ' ' + e.getMessage() + ' ' + e.getStackTraceString();
            system.debug('exception ' + e.getTypeName());
            system.debug('exception ' + e.getMessage());
            system.debug('exception ' + e.getStackTraceString());
        }
        return rWrap;

    }
    
    @AuraEnabled(cacheable=true)
    public static list<sObject> fetchLookupData(string searchKey ,String corelocation, string sObjectApiName, string additionalCondition) {    
        List <sObject> returnList = new List <sObject> (); 
        string sWildCardText = '%' + searchKey + '%';
        string sQuery = 'Select Id,ProductCode,Name,NAOCAP_Core_Return_Location__c From ' + sObjectApiName + ' Where ProductCode Like : sWildCardText AND RecordType.Name = \'NAC Products\' AND NAOCAP_Core_Return_Location__c INCLUDES(\''+String.escapeSingleQuotes(corelocation)+'\'' +') order by createdDate DESC LIMIT 5';
        for (sObject obj: database.query(sQuery)) {
            returnList.add(obj);
        }
        return returnList;
    }
    
    public class caseWrapper{
        @AuraEnabled public List<sections> coreFields;
        @AuraEnabled public List<sections> performancePartsFields;
        @AuraEnabled public List<ContactPointAddress> addressList;        
        caseWrapper(){
            coreFields = new List<sections>();
            performancePartsFields = new List<sections>();
            addressList = new List<ContactPointAddress>();
        }
    }
    
    public class sections{
        @AuraEnabled public string sectionLabel;
        @AuraEnabled public string sectionAPIName;
        @AuraEnabled public Integer order;
        @AuraEnabled public List<field> fieldList;
        sections(){
            order = 999;
            fieldList = new List<field>();
        }
    }
    
    public class field{
        @AuraEnabled public string apiName;
        @AuraEnabled public boolean isRequired;
        @AuraEnabled public boolean isReadOnly;
        @AuraEnabled public string value;
        field(Schema.FieldSetMember fsm){
            apiName = fsm.getFieldPath();
            User u=[Select Id,ContactId from User where Id=:UserInfo.getUserId() Limit 1];
            Contact currentContact =[SELECT Id,Name,AccountId,Account.CONTAINER_JDE_Bill_To_Code__c from Contact where Id=:u.ContactId Limit 1];
            isReadOnly = false;
            if(apiName == 'Origin'){
                isReadOnly = true;
                value='Origin';
            }
            if(fsm.getDbRequired() || fsm.getRequired()){
                isRequired = true;
            }else{
                isRequired = false;
            }
            if(apiName == 'Type'){
                isRequired = true;
            }
            value = null;
            if(apiName == 'AccountId'){
                isReadOnly = true;
                value= currentContact.AccountId;
            }
            if(apiName == 'NAC_Account_Number__c'){
                isReadOnly = true;
                value= currentContact.Account.CONTAINER_JDE_Bill_To_Code__c;
            }
            if(apiName == 'ContactId'){
                isReadOnly = true;
                value= u.ContactId;
            }
            if(apiName == 'NATT_Case_Reason__c'){
                value= '';
            }
        }
    }
    
    public class resultWrapper{
        @AuraEnabled public String caseId;
        @AuraEnabled public boolean hasError;
        @AuraEnabled public String errorMessage;
        resultWrapper(){
            hasError = false;
            errorMessage = '';
        }
    }

}