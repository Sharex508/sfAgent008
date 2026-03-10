public class NattNewContact {
    
    @AuraEnabled
    public static String getRtId(String recordId){
        Account a = [SELECT Id,RecordType.DeveloperName FROM Account WHERE Id=:recordId];
        Map<String,Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName();
        String rtId;
        if(a.RecordType.DeveloperName=='NATT_Competitor' && rtMap.get('NATT_Competitor').isAvailable()){
            rtId=rtMap.get('NATT_Competitor').getRecordTypeId();
        }else if(a.RecordType.DeveloperName=='Customer' && rtMap.get('NATT_End_Customer').isAvailable()){
            rtId=rtMap.get('NATT_End_Customer').getRecordTypeId();
        }else if(a.RecordType.DeveloperName=='Dealer' && rtMap.get('NATT_Dealer').isAvailable()){
            rtId=rtMap.get('NATT_Dealer').getRecordTypeId();
        }else if(a.RecordType.DeveloperName=='NATT_OEM' && rtMap.get('NATT_Direct_Sell_Internal').isAvailable()){//direct sale
            rtId=rtMap.get('NATT_Direct_Sell_Internal').getRecordTypeId();
        }else if(a.RecordType.DeveloperName=='NATT_Group_Ownership'){
           rtId=rtMap.get('NATT_Dealer').getRecordTypeId();
        }else if(a.RecordType.DeveloperName=='MX_Competitor' && rtMap.get('MX_Competitor').isAvailable()){
            rtId=rtMap.get('MX_Competitor').getRecordTypeId();
        }else if(a.RecordType.DeveloperName=='MX_Customer' && rtMap.get('MX_Customer').isAvailable()){//direct sale
            rtId=rtMap.get('MX_Customer').getRecordTypeId();
        }else if(a.RecordType.DeveloperName=='MX_Dealer' && rtMap.get('MX_Dealer').isAvailable()){
            rtId=rtMap.get('MX_Dealer').getRecordTypeId();
        }else if(a.RecordType.DeveloperName=='CTBR_Competitor' && rtMap.get('CTBR_Competitor').isAvailable()){
            rtId=rtMap.get('CTBR_Competitor').getRecordTypeId();
        }else if(a.RecordType.DeveloperName=='CTBR_Customer' && rtMap.get('CTBR_Customer').isAvailable()){
            rtId=rtMap.get('CTBR_Customer').getRecordTypeId();
        }else if(a.RecordType.DeveloperName=='CTBR_Dealer' && rtMap.get('CTBR_Dealer').isAvailable()){
            rtId=rtMap.get('CTBR_Dealer').getRecordTypeId();
        }
        else if(a.RecordType.DeveloperName=='Internal' && rtMap.get('NATT_Direct_Sell_Internal').isAvailable()){
            rtId=rtMap.get('NATT_Direct_Sell_Internal').getRecordTypeId();
        }
        
        return rtId;
    }
}