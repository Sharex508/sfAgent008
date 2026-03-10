@IsTest
public class NATT_MyProgressControllerTest {
    
    @TestSetup
    static void makeData(){
        
        SBQQ__Quote__c newQuote = new SBQQ__Quote__c(
            SBQQ__Status__c = NATT_Constants.QUOTE_DRAFT,
            RecordTypeId = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get(NATT_Constants.QUOTE_NATT_UNIT_RT).getRecordTypeId()
        );
        Insert newQuote;
        
        SBQQ__Quote__c newQuote2 = new SBQQ__Quote__c(
            SBQQ__Status__c = NATT_Constants.QUOTE_DRAFT,
            RecordTypeId = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get(NATT_Constants.QUOTE_NATT_UNIT_RT).getRecordTypeId()
        );
        Insert newQuote2;
        
        Test.setCreatedDate(newQuote2.Id, System.now().addDays(-1));
        
        SBQQ__Quote__c newQuote3 = new SBQQ__Quote__c(
            SBQQ__Status__c = NATT_Constants.QUOTE_DRAFT,
            RecordTypeId = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get(NATT_Constants.QUOTE_NATT_UNIT_RT).getRecordTypeId()
        );
        Insert newQuote3;
        
        Test.setCreatedDate(newQuote3.Id, System.now().addDays(-8));

        /* ---- */

        Account newAccount = new Account(
            Name = 'Account Test 1'
        );
        Insert newAccount;

        Order newOrder = new Order(
            Name = 'Order Test 1',
            AccountId = newAccount.Id,
            NATT_Order_Status__c = NATT_Constants.ORDER_STATUS_IN_PROGRESS.get(0),
            RecordTypeId = Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get(NATT_Constants.ORDER_NATT_UNIT_RT).getRecordTypeId(),
            EffectiveDate = System.today(),
            Status = 'Draft'
        );
        Insert newOrder;
        
        Order newOrder2 = new Order(
            Name = 'Order Test 2',
            AccountId = newAccount.Id,
            NATT_Order_Status__c = NATT_Constants.ORDER_STATUS_IN_PROGRESS.get(0),
            RecordTypeId = Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get(NATT_Constants.ORDER_NATT_UNIT_RT).getRecordTypeId(),
            EffectiveDate = System.today(),
            Status = 'Draft'
        );
        Insert newOrder2;
        Test.setCreatedDate(newOrder2.Id, System.now().addDays(-1));
        
        Order newOrder3 = new Order(
            Name = 'Order Test 3',
            AccountId = newAccount.Id,
            NATT_Order_Status__c = NATT_Constants.ORDER_STATUS_IN_PROGRESS.get(0),
            RecordTypeId = Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get(NATT_Constants.ORDER_NATT_UNIT_RT).getRecordTypeId(),
            EffectiveDate = System.today().addDays(-1),
            Status = 'Draft'
        );
        Insert newOrder3;
        Test.setCreatedDate(newOrder3.Id, System.now().addDays(-8));
        
        /* ---- */

        Case newCase = new Case(
            Status = NATT_Constants.CASE_STATUS_IN_PROGRESS.get(0)
        );
        Insert newCase;
        
        Case newCase2 = new Case(
            Status = NATT_Constants.CASE_STATUS_IN_PROGRESS.get(0)
        );
        Insert newCase2;
        Test.setCreatedDate(newCase2.Id, System.now().addDays(-1));
        
        Case newCase3 = new Case(
            Status = NATT_Constants.CASE_STATUS_IN_PROGRESS.get(0)
        );
        Insert newCase3;
        Test.setCreatedDate(newCase3.Id, System.now().addDays(-8));

    }

    @IsTest
    static void getMyProgressSummaryTest(){
        
        Test.startTest();
            Map<String, Object> mpReturn = NATT_MyProgressController.getMyProgressSummary('Week');
            System.assertEquals(true, mpReturn.get('success'));
        
        Test.stopTest();
        
    }
    
    @IsTest
    static void getCountQuotesInProgressTest(){
        
        Test.startTest();
        	NATT_MyProgressController.periodProgress = 'TODAY';
            Integer countNumber = NATT_MyProgressController.getCountQuotesInProgress();
            System.assertEquals(1, countNumber);
        
        	NATT_MyProgressController.periodProgress = 'THIS_WEEK';
            Integer countNumber2 = NATT_MyProgressController.getCountQuotesInProgress();
            System.assertEquals(3, countNumber2);
        
        	NATT_MyProgressController.periodProgress = 'THIS_MONTH';
            Integer countNumber3 = NATT_MyProgressController.getCountQuotesInProgress();
            System.assertEquals(3, countNumber3);        
        Test.stopTest();
        
    }    
    
    @IsTest
    static void getCountOrdersInProgressTest(){
        
        Test.startTest();
        	NATT_MyProgressController.periodProgress = 'TODAY';
            Map<String, Integer> mapCountNumber = NATT_MyProgressController.getCountOrdersInProgress();
            System.assertEquals(1, mapCountNumber.get('NATT_Units_Order'));
        
        	NATT_MyProgressController.periodProgress = 'THIS_WEEK';
            Map<String, Integer> mapCountNumber2 = NATT_MyProgressController.getCountOrdersInProgress();
            System.assertEquals(3, mapCountNumber2.get('NATT_Units_Order'));
        
        	NATT_MyProgressController.periodProgress = 'THIS_MONTH';
            Map<String, Integer> mapCountNumber3 = NATT_MyProgressController.getCountOrdersInProgress();
            System.assertEquals(3, mapCountNumber3.get('NATT_Units_Order'));
        Test.stopTest();
        
    }
    
    @IsTest
    static void getCountCasesInProgressTest(){
        
        Test.startTest();
        	NATT_MyProgressController.periodProgress = 'TODAY';
            Integer countNumber = NATT_MyProgressController.getCountCasesInProgress();
            System.assertEquals(1, countNumber);
        
        	NATT_MyProgressController.periodProgress = 'THIS_WEEK';
            Integer countNumber2 = NATT_MyProgressController.getCountCasesInProgress();
            System.assertEquals(3, countNumber2);
        
        	NATT_MyProgressController.periodProgress = 'THIS_MONTH';
            Integer countNumber3 = NATT_MyProgressController.getCountCasesInProgress();
            System.assertEquals(3, countNumber3);
        Test.stopTest();
        
    }

    @IsTest
    static void setParamPeriodTest(){
        
        Test.startTest();
            String paramPeriodDay = NATT_MyProgressController.setParamPeriod('Day');
            System.assertEquals('TODAY', paramPeriodDay);

            String paramPeriodWeek = NATT_MyProgressController.setParamPeriod('Week');
            System.assertEquals('THIS_WEEK', paramPeriodWeek);

            String paramPeriodMonth = NATT_MyProgressController.setParamPeriod('Month');
            System.assertEquals('THIS_MONTH', paramPeriodMonth);
        Test.stopTest();
        
    }

}