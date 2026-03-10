public with sharing class NATT_MyProgressController {

    public static String periodProgress;

    @AuraEnabled
    public static Map<String, Object> getMyProgressSummary(String period) {
        Map<String, Object> mpReturn = new Map<String, Object>{'success' => true, 'message' => '', 'quoteIsAccessible' => NATT_Utils.isAccessible('SBQQ__Quote__c'), 'orderIsAccessible' => NATT_Utils.isAccessible('Order'), 'caseIsAccessible' => NATT_Utils.isAccessible('Case'), 'claimIsAccessible' => true};
        periodProgress = setParamPeriod(period);

        try {

            mpReturn.put('countQuotesInProgress', getCountQuotesInProgress());
            mpReturn.put('countOrdersInProgress', getCountOrdersInProgress());
            mpReturn.put('countCasesInProgress', getCountCasesInProgress());
            mpReturn.put('countClaimsInProgress', getCountClaimsInProgress());

        } catch (AuraHandledException e) {
            mpReturn.put('success', false);
            mpReturn.put('message', e.getMessage());
        }
        
        return mpReturn;
    }

    @TestVisible
    private static Integer getCountQuotesInProgress() {
        Integer countNumber = 0;

        try {
            
            if (periodProgress == 'TODAY') {
                countNumber = [SELECT COUNT() FROM SBQQ__Quote__c WHERE SBQQ__Status__c IN :NATT_Constants.QUOTE_STATUS_IN_PROGRESS AND RecordType.DeveloperName = :NATT_Constants.QUOTE_NATT_UNIT_RT AND CreatedDate = TODAY];
            } else if (periodProgress == 'THIS_WEEK') {
                countNumber = [SELECT COUNT() FROM SBQQ__Quote__c WHERE SBQQ__Status__c IN :NATT_Constants.QUOTE_STATUS_IN_PROGRESS AND RecordType.DeveloperName = :NATT_Constants.QUOTE_NATT_UNIT_RT AND CreatedDate <= THIS_WEEK];
            } else if (periodProgress == 'THIS_MONTH') {
                countNumber = [SELECT COUNT() FROM SBQQ__Quote__c WHERE SBQQ__Status__c IN :NATT_Constants.QUOTE_STATUS_IN_PROGRESS AND RecordType.DeveloperName = :NATT_Constants.QUOTE_NATT_UNIT_RT AND CreatedDate <= THIS_MONTH];
            }

            //countNumber = Database.countQuery('SELECT COUNT() FROM SBQQ__Quote__c WHERE SBQQ__Status__c IN ' + NATT_Constants.QUOTE_STATUS_IN_PROGRESS + ' AND CreatedDate < ' + periodProgress);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        return countNumber;
    }
    
    @TestVisible
    private static Map<String, Integer> getCountOrdersInProgress() {
        Map<String, Integer> mpOrderTypeCount = new Map<String, Integer>();
        List<AggregateResult> ltAggregateOrder = new List<AggregateResult>();
        
        try {

            if (periodProgress == 'TODAY') {
                ltAggregateOrder = [SELECT COUNT(Id), RecordType.DeveloperName FROM Order WHERE NATT_Order_Status__c IN :NATT_Constants.ORDER_STATUS_IN_PROGRESS AND CreatedDate = TODAY GROUP BY RecordType.DeveloperName];
            } else if (periodProgress == 'THIS_WEEK') {
                ltAggregateOrder = [SELECT COUNT(Id), RecordType.DeveloperName FROM Order WHERE NATT_Order_Status__c IN :NATT_Constants.ORDER_STATUS_IN_PROGRESS AND CreatedDate <= THIS_WEEK GROUP BY RecordType.DeveloperName];
            } else if (periodProgress == 'THIS_MONTH') {
                ltAggregateOrder = [SELECT COUNT(Id), RecordType.DeveloperName FROM Order WHERE NATT_Order_Status__c IN :NATT_Constants.ORDER_STATUS_IN_PROGRESS AND CreatedDate <= THIS_MONTH GROUP BY RecordType.DeveloperName];
            }

            System.debug('ltAggregateOrder: ' + ltAggregateOrder);

            if (ltAggregateOrder.isEmpty()) {
                mpOrderTypeCount.put( 'NATT_Units_Order', 0);
                mpOrderTypeCount.put( 'NATT_Parts_Order', 0);
            } else {
                for (AggregateResult aggregateOrder : ltAggregateOrder) {
                    mpOrderTypeCount.put( (String) aggregateOrder.get('DeveloperName'), (Integer) aggregateOrder.get('expr0'));
                }
            }
            
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        
        System.debug('mpOrderTypeCount: ' + mpOrderTypeCount);
        return mpOrderTypeCount;
    }
    
    @TestVisible
    private static Integer getCountCasesInProgress() {
        Integer countNumber = 0;
        
        try {

            if (periodProgress == 'TODAY') {
                countNumber = [SELECT COUNT() FROM Case WHERE Status IN :NATT_Constants.CASE_STATUS_IN_PROGRESS AND CreatedDate = TODAY];
            } else if (periodProgress == 'THIS_WEEK') {
                countNumber = [SELECT COUNT() FROM Case WHERE Status IN :NATT_Constants.CASE_STATUS_IN_PROGRESS AND CreatedDate <= THIS_WEEK];
            } else if (periodProgress == 'THIS_MONTH') {
                countNumber = [SELECT COUNT() FROM Case WHERE Status IN :NATT_Constants.CASE_STATUS_IN_PROGRESS AND CreatedDate <= THIS_MONTH];
            }
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        
        return countNumber;
    }
    
    @TestVisible
    private static Integer getCountClaimsInProgress() {
        Integer countNumber = 0;
        
        try {

            /*if (periodProgress == 'TODAY') {
                countNumber = [SELECT COUNT() FROM SBQQ__Quote__c WHERE SBQQ__Status__c IN :NATT_Constants.QUOTE_STATUS_IN_PROGRESS AND CreatedDate = TODAY];
            } else if (periodProgress == 'THIS_WEEK') {
                countNumber = [SELECT COUNT() FROM SBQQ__Quote__c WHERE SBQQ__Status__c IN :NATT_Constants.QUOTE_STATUS_IN_PROGRESS AND CreatedDate <= THIS_WEEK];
            } else if (periodProgress == 'THIS_MONTH') {
                countNumber = [SELECT COUNT() FROM SBQQ__Quote__c WHERE SBQQ__Status__c IN :NATT_Constants.QUOTE_STATUS_IN_PROGRESS AND CreatedDate <= THIS_MONTH];
            }*/
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        
        System.debug('countNumber: ' + countNumber);
        return countNumber;
    }

    @TestVisible
    private static String setParamPeriod(String period) {
        String constantPeriod = '';

        switch on period {
            when 'Day' {
                constantPeriod = 'TODAY';
            }
            
            when 'Week' {
                constantPeriod = 'THIS_WEEK';
            }

            when 'Month' {
                constantPeriod = 'THIS_MONTH';
            }
        }

        return constantPeriod;
    }
    
}