public with sharing class NATT_CustomListViewCon {

    @AuraEnabled( cacheable = false )  
    public static List < sObject > fetchRecs( String listValues, String jsonFilter, integer offSetCount) { 
        //System.debug('carrierOrderNumber:'+carrierOrderNumber);
        //system.debug( 'values are ' + listValues );  
        List < String > strList = listValues.split( '-' );  
        //System.debug( 'values are ' + strList +' size:'+strList.size());   
        String strObject = strList.get( 0 );
        String strFields = strList.get( 1 );
        String strRelatedField = strList.get( 2 );
        String strAccountId;
        
        if ( strList.size() == 4){
            strAccountId = strList.get( 3 );
            //System.debug('setAccountId:'+strAccountId);
        }
        
        List < sObject > listRecs = new List < sObject >();
        String soql = 'SELECT Id, ' + strFields + ' FROM ' + strObject +' WHERE RecordType.DeveloperName=\'NATT_Parts_Order\' ';

        /*if ( String.isNotBlank( strAccountId ) ){
            soql  += ' AND ' + strRelatedField+ ' = :strAccountId';
        }*/   
        if(strObject=='Order'){
            /*if(!saveSearch){
                List<NATT_PersistentSearchFilter__c> searchFilterList = new List<NATT_PersistentSearchFilter__c>([SELECT Id,NATT_SearchFilter__c FROM NATT_PersistentSearchFilter__c WHERE NATT_UserId__c=:UserInfo.getUserId()]);
                if(!searchFilterList.isEmpty()){
                    jsonFilter = searchFilterList.get(0).NATT_SearchFilter__c;
                }
            }*/
            Object o = JSON.deserializeUntyped(jsonFilter);
            Map<String, Object> fieldMap = (Map<String, Object>) o;
            String carrierOrderNumber = (String)fieldMap.get('carrierOrderNumber');
            String poOrAccount = (String)fieldMap.get('poOrAccount');
            String partNumber = (String)fieldMap.get('partNumber');
            String status = (String)fieldMap.get('status');
            String fromDate = (String)fieldMap.get('fromDate');
            String toDate = (String)fieldMap.get('toDate');
            String sortedBy = (String)fieldMap.get('sortedBy');
            if(sortedBy=='OrderNumberId'){
                sortedBy='OrderNumber';
            }else if(sortedBy=='AccountNameId'){
                sortedBy='NATT_Account_Name__c';
            }
            String sortDirection = (String)fieldMap.get('sortDirection');
            
            if(String.isNotBlank(carrierOrderNumber)){
                carrierOrderNumber= '%'+carrierOrderNumber+'%';
                soql+=' AND NATT_JDE_Sales_Order_Number__c like :carrierOrderNumber';
            }
            if(String.isNotBlank(poOrAccount)){
                poOrAccount= '%'+poOrAccount+'%';
                soql+=' AND (NATT_Purchase_Order__c like :poOrAccount OR Account.NATT_JDE_Parts_Bill_To_Code__c like :poOrAccount)';
            }            
            if(String.isNotBlank(partNumber)){                
                Set<Id> orderIdSet = searchOrders(partNumber);
                soql+= ' AND Id in :orderIdSet';
            }
            if(String.isNotBlank(status)){
                soql+=' AND NATT_Order_Status__c=:status';
            }
            if(String.isNotBlank(fromDate)){
                Date fromDateValue = Date.valueOf(fromDate);
                soql+=' AND EffectiveDate>=:fromDateValue';
            }
            if(String.isNotBlank(toDate)){
                Date toDateValue = Date.valueOf(toDate);
                soql+=' AND EffectiveDate<=:toDateValue';
            }
            
            soql+=' ORDER BY '+sortedBy+' '+sortDirection;
        }
        soql += '  LIMIT 100 OFFSET :offSetCount';
        system.debug( 'SOQL is ' + soql );
        listRecs = Database.query( soql );
        //save the last query that was performed        
        upsertFilter(jsonFilter);        

        return listRecs;          
    }  
    
    private static void upsertFilter(String jsonFilter) { 
        NATT_PersistentSearchFilter__c filter = new NATT_PersistentSearchFilter__c(NATT_UserId__c=UserInfo.getUserId(),NATT_SearchFilter__c=jsonFilter);
        upsert filter NATT_UserId__c;
    }

    @AuraEnabled( cacheable = false )  
    public static NATT_PersistentSearchFilter__c getPersistentFilter() { 
        NATT_PersistentSearchFilter__c filter = new NATT_PersistentSearchFilter__c(NATT_UserId__c=UserInfo.getUserId(),NATT_SearchFilter__c='{"carrierOrderNumber":"","poOrAccount":"","partNumber":"","fromDate":"","toDate":"","sortedBy":"CreatedDate","sortDirection":"DESC"}');
        List<NATT_PersistentSearchFilter__c> filterList = new List<NATT_PersistentSearchFilter__c>([SELECT Id,NATT_SearchFilter__c FROM NATT_PersistentSearchFilter__c WHERE NATT_UserId__c=:UserInfo.getUserId()]);
        if(!filterList.isEmpty()){
            filter = filterList.get(0);
        }
        return filter;
    }    

    private static Set<Id> searchOrders(String searchValue){
        String soslSearchValue=searchValue+'*';
        String soqlSearchValue=searchValue+'%';
        List<List<SObject>> searchList = [FIND :soslSearchValue IN ALL FIELDS 
                                      RETURNING Order(Id)];
        Set<Id> orderIdSet = new Set<Id>();
        List<Order> orderList = (List<Order>)searchList.get(0);        
        for(Order o : orderList){
            orderIdSet.add(o.Id);
        }

        for(OrderItem oi : [SELECT Id,OrderId FROM OrderItem WHERE Product2.NATT_P_N__c like :soqlSearchValue+'%']){
            orderIdSet.add(oi.OrderId);
        }
        
        return orderIdSet;
    }
}