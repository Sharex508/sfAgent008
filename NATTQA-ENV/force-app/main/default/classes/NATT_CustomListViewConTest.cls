@IsTest
private class NATT_CustomListViewConTest {
	@IsTest
    static void myUnitTest(){        
        String valueList = 'Order-OrderNumber,NATT_Purchase_Order__c,NATT_JDE_Sales_Order_Number__c,NATT_JdeOrderTypeName__c,NATT_Order_Status__c,EffectiveDate,LastModifiedDate,TotalAmount,CurrencyIsoCode-AccountId-';
        String jsonFilter='{"carrierOrderNumber":"","poOrAccount":"","partNumber":"asdf123","status":"","fromDate":"","toDate":"","sortedBy":"CreatedDate","sortDirection":"DESC"}';
        NATT_CustomListViewCon.fetchRecs(valueList, jsonFilter,0);

        NATT_PersistentSearchFilter__c filter = NATT_CustomListViewCon.getPersistentFilter();
    }
}