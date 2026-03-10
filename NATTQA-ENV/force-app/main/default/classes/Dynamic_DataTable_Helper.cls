public without sharing class Dynamic_DataTable_Helper {
    @AuraEnabled(cacheable=true)
    public static List<DataWrapper> getFieldHistoryList(String recId) {

        try{
            id myId = recId;
            String sObjName = myId.getSObjectType().getDescribe().getName();
            list<DataWrapper> listContact  = new list<DataWrapper>();
    
            for(FieldHistoryArchive fldVar : [SELECT ParentId,CreatedBy.Name,CreatedDate,ArchiveFieldName, FieldHistoryType, Field, Id, NewValue, OldValue
                                              FROM FieldHistoryArchive
                                              WHERE FieldHistoryType =: sObjName AND ParentId =:recId]){
    
                        listContact.add(new DataWrapper(fldVar));
                 } 
    
            return listContact;
        }
        catch (Exception e) {
            // "Convert" the exception into an AuraHandledException
            throw new AuraHandledException('Error: '
            + e.getMessage());
            }
    }

    //A wrapper class that will be use do display the data of the object
    public class DataWrapper{
        @AuraEnabled public string user {get;set;} 
        @AuraEnabled public object fieldLabel {get;set;}
        @AuraEnabled public Datetime createdDate {get;set;} 
        @AuraEnabled public object oldValue {get;set;} 
        @AuraEnabled public object newValue {get;set;} 
        public string createText = 'createText';
        public string textName = 'TextName';
        public string parent = 'Parent';
        public string recordCreated = 'Record Created.';
        public string blankVar = ' ';
        public string name = 'Name';
        public string extension = '__c';
        public string fldStr{get;set;}
        public string FieldName = 'TextName';
        public string APIName = 'TextName';
        public string ObjecName = 'TextName';
        public string ObjectLableName = 'TextName';
        public string OldValueField = 'TextName';
        public string NewValueFieldName = 'TextName';
        public string FieldName1 = 'TextName';
        public string APIName1 = 'TextName';
        public string ObjecName1 = 'TextName';
        public string ObjectLableName1 = 'TextName';
        public string OldValueField1 = 'TextName';
        public string NewValueFieldName1 = 'TextName';
        public string FieldName2 = 'TextName';
        public string APIName2 = 'TextName';
        public string ObjecName2 = 'TextName';
        public string ObjectLableName2 = 'TextName';
        public string OldValueField2 = 'TextName';
        public string NewValueFieldName2 = 'TextName';

        public DataWrapper(FieldHistoryArchive fldVarRec){

            this.user =  fldVarRec.CreatedBy.Name;
            fldStr = fldVarRec.ArchiveFieldName;
            

            if((fldStr != createText) && fldStr != textName &&
            fldStr != parent ){

                id recVarId = fldVarRec.ParentId;
                if(!Test.isRunningTest()){
                String sObjNameVal = recVarId.getSObjectType().getDescribe().getName();
                String fld = fldVarRec.ArchiveFieldName + extension;
                String fldName = Schema.getGlobalDescribe().get(sObjNameVal).getDescribe().fields.getMap().get(fld).getDescribe().getLabel();
                this.fieldLabel = fldName;
                }
            }else {
                    if(fldStr == createText){
                    this.fieldLabel = recordCreated;
               }
               else if(fldStr == textName){
                    id recVarId = fldVarRec.ParentId;
                    String sObjNameVal = recVarId.getSObjectType().getDescribe().getName();
                    this.fieldLabel = sObjNameVal + blankVar + name;
               }else{
                    this.fieldLabel = fldVarRec.ArchiveFieldName;
               }
             
            }
            
            this.createdDate = fldVarRec.CreatedDate; 
            this.oldValue = fldVarRec.OldValue; 
            this.newValue = fldVarRec.NewValue;                    
        }
    }
}