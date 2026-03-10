/********************************************************************************************************
* @author         (Deloitte)
* @description    This class is for PAR Export Functionality.
* @date           05/04/2023 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Deloitte               05/04/2023                                  Initial version
*********************************************************************************************************/
public with sharing class NATT_ParExportToCsvController{
    @AuraEnabled
    public static List<NATT_PAR__c> getPARList(string accId){
        List<NATT_PAR__c> parlist = new List<NATT_PAR__c>();
        
        if(Site.getSiteType() != null){
           parlist = [SELECT Id, Name, NATT_Country__c, NATT_State__c, NATT_County__c, NATT_Trailer__c, NATT_Truck__c
                                     FROM NATT_PAR__c 
                                     where NATT_Account__c =:accId
                                     Order by Name];
        }else{
            parlist = [SELECT Id, Name, NATT_Country__c, NATT_State__c, NATT_County__c, NATT_Trailer__c, NATT_Truck__c, NATT_Special_Products__c	
                                     FROM NATT_PAR__c 
                                     where NATT_Account__c =:accId
                                     Order by Name];
        }
       
        if(!parlist.isEmpty()){
            if (parlist[0].NATT_Country__c == null){
                parlist[0].NATT_Country__c = 'ReplaceCountryNull';
            }if (parlist[0].NATT_State__c == null){
                parlist[0].NATT_State__c = 'ReplaceStateNull';
            }if (parlist[0].NATT_County__c == null){
                parlist[0].NATT_County__c = 'ReplaceCountyNull';
            }
        }
        
        return parlist;
    }
    
    @AuraEnabled
    public static account getAccountName(string accId){
        return [SELECT id, Name FROM Account where id =:accId];
    }
}