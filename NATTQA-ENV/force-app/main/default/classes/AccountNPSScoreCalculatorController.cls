/*****************************************************************************************************************************************************************************************
* NAME          : AccountNPSScoreCalculatorController
* @description  : Controller class for accountNPSScoreCalculatorLWC
* @author       : Satya Swain   
* @date         : 12-Sep-2023
* @testclasses : AccountNPSScoreCalculatorControllerTest
* MODIFICATION LOG:  
* --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
* DEVELOPER                DATE                DESCRIPTION 
* --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Satya Swain            12-Sep-2023           CCE-486 : Initial Version
****************************************************************************************************************************************************************************************
*/ 
public without sharing class AccountNPSScoreCalculatorController {
    
    /** 
    * @description - Calculates the NPS score for a given account and date range
    * @param String accountId
    * @param String strRange
    * @return String
    */
    @AuraEnabled
    public static String calculateScore(String accountId, String strRange) {
        Decimal decPromoterCount = 0;
        Decimal decDetractorCount = 0;
        Integer intTotalResponsesCount = 0;
        
        String strQueryForAllRecords = getSOQLQueryString(accountId, strRange, '');
                            
        List<AggregateResult> lstAggregateResponse = Database.query(strQueryForAllRecords);
        
        if(lstAggregateResponse == null || lstAggregateResponse.isEmpty() || lstAggregateResponse[0].get('responseCount') == 0 ) {             
            return '{"decPromoterPercentage" : '+0
                + ',"decDectractorPercentage": '+0
                + ',"strMessage": '+ '"No responses returned"' + '}';
        }

        String strQueryForPromoter = getSOQLQueryString(accountId, strRange, 'Promoter');
        String strQueryForDetractor = getSOQLQueryString(accountId, strRange, 'Detractor');
        
        List<AggregateResult> lstPromoterAggregateResponse = Database.query(strQueryForPromoter);
        List<AggregateResult> lstDetractorAggregateResponse = Database.query(strQueryForDetractor);

        intTotalResponsesCount = (Integer) lstAggregateResponse[0].get('responseCount');
        decPromoterCount = (Decimal) lstPromoterAggregateResponse[0].get('responseCount');
        decDetractorCount = (Decimal) lstDetractorAggregateResponse[0].get('responseCount');
                
        System.debug('decPromoterCount ::: '+decPromoterCount);
        System.debug('decDetractorCount ::: '+decDetractorCount);
        Decimal decPromoterPercentage = (Decimal) (decPromoterCount/intTotalResponsesCount) * 100;
        Decimal decDectractorPercentage = (Decimal) (decDetractorCount/intTotalResponsesCount) * 100;

        System.debug('intTotalResponsesCount ::: '+intTotalResponsesCount);
        System.debug('decPromoterPercentage ::: '+decPromoterPercentage);
        System.debug('decDectractorPercentage ::: '+decDectractorPercentage);

        Decimal decNPSScoreForAccount = decPromoterPercentage - decDectractorPercentage;
        System.debug('decNPSScoreForAccount ::: '+decNPSScoreForAccount);
        return '{"decPromoterPercentage" : '+ decPromoterPercentage.setScale(2)
                + ',"decDectractorPercentage": '+ decDectractorPercentage.setScale(2)
                + ',"decNPSScoreForAccount": '+ decNPSScoreForAccount.setScale(2)
                + ',"intTotalResponsesCount": '+intTotalResponsesCount
                + ',"strMessage": '+ '"success"' + '}';

    }
    
    /** 
    * @description - Generates the dynamic SOQL for querying nps_Feedback__c
    * @param String accountId
    * @param String strRange
    * @return String
    */
    public static String getSOQLQueryString(String accountId, String strRange, String strTypeOfResponse) {        
        String strQuery = 'SELECT COUNT(id) responseCount '
                        +'FROM nps_Feedback__c ' 
                        +'WHERE nps_Contact_Id__r.AccountId = :accountId ';
        
        if(strTypeOfResponse == 'Promoter') {
            strQuery += 'AND nps_Response_Main_score__c >= 9 ';
        } else if(strTypeOfResponse == 'Detractor') {
            strQuery += 'AND nps_Response_Main_score__c <= 6 ';
        }

        String strRangeClause = getWhereClauseBasedOnTimeRange(strRange);
        strQuery += strRangeClause;
        
        return strQuery;
    }

    /** 
    * @description - Generates where clause based on Time Range    
    * @param String strRange
    * @return String
    */
    public static String getWhereClauseBasedOnTimeRange(String strRange) {
        String strReturnClause = '';
        
        if(strRange == 'This Year') {
           strReturnClause = 'AND nps_Response_Date__c = THIS_YEAR';
        } else if (strRange == 'This Quarter') {
            strReturnClause = 'AND nps_Response_Date__c = THIS_QUARTER';
        } else if(strRange == 'This Month') {
            strReturnClause = 'AND nps_Response_Date__c = THIS_MONTH';
        } else if(strRange == 'Last Year') {
            strReturnClause = 'AND nps_Response_Date__c = LAST_YEAR';
        } else if(strRange == 'All Time') {
            strReturnClause = '';
        }

        return strReturnClause;
    }
}