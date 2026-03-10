public class NAC_BackorderReportHelper {
    
   public class TopBackorderWrapper implements Comparable{
        @AuraEnabled public String Id {get;set;}
        @AuraEnabled public String partNumber {get;set;}
        @AuraEnabled public Decimal quantity {get;set;}
        
        public integer compareTo(Object recordToCompare){
            TopBackorderWrapper boWrap = (TopBackorderWrapper)recordToCompare;
            if(quantity > boWrap.quantity) 
                return 0;
            else 
                return 1;            
        }
    }
    
    // public Class TopBackorderWrapperList {
    //     @AuraEnabled public List < TopBackorderWrapper > backorderItems{get;set;}
    
    // }
    
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getOrderList() {
        System.debug('#####' + ConnectApi.Communities.getCommunities());
        List<Map<String, Object>> result = new List<Map<String, Object>>();
         List<OrderItem> orderItemList  = new  List<OrderItem> ();
        if(Test.isRunningTest()){
             orderItemList = [
            SELECT Id, Order_Date__c, Order_Number__c, Purchase_Order_Number__c, Customer__c,NAC_Note__c, PartsNet__c, Depot__c, Parent_Order_Type__c, Part_Number__c, Description__c,Quantity, NATT_Shipped_Quantity__c,NATT_Backordered_Quantity__c, Estimated_Availability__c, Total_Shipped_of_Total_Ordered__c,
            order.NATT_Shipping_Address__r.NATT_JDE_Alpha_Name__c,OrderItem.Direct_Delivery__c,OrderItem.NATT_Available_Promise_Date__c
            FROM OrderItem 
            WHERE NATT_Backordered_Quantity__c > 0 limit 1];
        }
        else {
        orderItemList = [
            SELECT Id, Order_Date__c, Order_Number__c, Purchase_Order_Number__c, Customer__c,NAC_Note__c, PartsNet__c, Depot__c, Parent_Order_Type__c, Part_Number__c, Description__c,Quantity, NATT_Shipped_Quantity__c,NATT_Backordered_Quantity__c, Estimated_Availability__c, Total_Shipped_of_Total_Ordered__c,
            order.NATT_Shipping_Address__r.NATT_JDE_Alpha_Name__c,OrderItem.Direct_Delivery__c,OrderItem.NATT_Available_Promise_Date__c
            FROM OrderItem 
            WHERE NATT_Backordered_Quantity__c > 0 ];
        }
        for (OrderItem item: orderItemList){
            //if else statement that populates the Direct Delivery field
            if (item.Direct_Delivery__c == true){
                item.Estimated_Availability__c = 'Direct';
            } else if (item.NATT_Available_Promise_Date__c == null) {
                
                item.Estimated_Availability__c = '0000-00-00 (Estimated)';
            } else {
                item.Estimated_Availability__c = item.NATT_Available_Promise_Date__c.format();
            }
            
            //logic that populates the Total Shipped of Total Ordered field
            String totalShipped = '0';
            String totalOrdered = '0';
            if(item.NATT_Shipped_Quantity__c != null){
                totalShipped = String.valueOf(item.NATT_Shipped_Quantity__c);
            }
            if(item.Quantity != null){
                totalOrdered = String.valueOf(item.Quantity);
                totalOrdered = totalOrdered.remove('.00');
            }
            item.Total_Shipped_of_Total_Ordered__c = (totalShipped + ' of ' + totalOrdered);
            /*if(item.Last_Update__c != null){
System.debug('OrderId: ' + item.OrderId + '|| LastUpdate: ' + item.Last_Update__c.format());
System.debug('Order Value Grab: ' + item.Order.NATT_Last_Update__c);

}*/
            Map<String, Object> orderMap = new Map<String, Object>();
            // Add the first 10 fields to the map
            //     orderMap.put('Id', item.Id);
            orderMap.put('Order_Date__c', item.Order_Date__c);
            orderMap.put('Order_Number__c', item.Order_Number__c);
            orderMap.put('Purchase_Order_Number__c', item.Purchase_Order_Number__c);
            orderMap.put('Customer__c', item.Customer__c);
            orderMap.put('PartsNet__c', item.PartsNet__c);
            //  orderMap.put('Depot__c', item.Depot__c);
            orderMap.put('Parent_Order_Type__c', item.Parent_Order_Type__c);
            orderMap.put('Part_Number__c', item.Part_Number__c);
            orderMap.put('Description__c', item.Description__c);
            orderMap.put('Quantity', item.Quantity);
            orderMap.put('NATT_Shipped_Quantity__c', item.NATT_Shipped_Quantity__c);
            orderMap.put('NATT_Backordered_Quantity__c', item.NATT_Backordered_Quantity__c);
            orderMap.put('Estimated_Availability__c', item.Estimated_Availability__c);
            orderMap.put('NAC_Note__c', item.NAC_Note__c);
            orderMap.put('Total_Shipped_of_Total_Ordered__c', item.Total_Shipped_of_Total_Ordered__c);
            //  orderMap.put('order.NATT_Shipping_Address__r.NATT_JDE_Alpha_Name__c', item.order.NATT_Shipping_Address__r.NATT_JDE_Alpha_Name__c);
            
            result.add(orderMap);         
        }
        
        
        
        
        return result;
    }
    
    /**
* Search functionality that takes search fields as input and returns list of queried objects
* - Checks to see which field is popualated and makes a query based on field
* - Combines all queried OrderItems into one List 
* - Creates a set of unique IDs to use in return query for updated Table
*/
    @AuraEnabled
    public static List<Map<String, Object>> getResults(String orderNumber, String poNumber, String partNumber, Date fromDate, Date toDate) { 
        List<Map<String, Object>> result1 = new List<Map<String, Object>>();
        
        System.debug('Part Num start: ' + partNumber);
        List <OrderItem> finalItems = new List <OrderItem>();
       
        string soqlResult = 'SELECT Id, Order_Date__c, Order_Number__c, Purchase_Order_Number__c, Customer__c,NAC_Note__c, PartsNet__c, Depot__c, Order_Type__c, Part_Number__c, Description__c, NATT_Backordered_Quantity__c,Total_Shipped_of_Total_Ordered__c,Parent_Order_Type__c,Estimated_Availability__c,Direct_Delivery__c,NATT_Available_Promise_Date__c,NATT_Shipped_Quantity__c,Quantity FROM OrderItem WHERE Id != null AND (NATT_Backordered_Quantity__c != 0 AND NATT_Backordered_Quantity__c != null) ';
      
        if (orderNumber != null){
            soqlResult += 'AND Order_Number__c LIKE \'%'+orderNumber+'%\' ';
        }
        if (poNumber != null){
            soqlResult += 'AND Purchase_Order_Number__c LIKE \'%'+poNumber+'%\' ';
        }
        if (partNumber != null){
            soqlResult += 'AND Part_Number__c LIKE \'%'+partNumber+'%\' ';
        }
        if(fromDate != null && toDate != null){
            String formatFrom = String.valueOf(fromDate).removeEnd(' 00:00:00');
            String formatTo = String.valueOf(toDate.addDays(1)).removeEnd(' 00:00:00');
            soqlResult += 'AND Order_Date__c > ' + formatFrom + ' AND Order_Date__c <= ' + formatTo + ' ';
            
        } else if (fromDate != null && toDate == null){
            String formatFrom = String.valueOf(fromDate).removeEnd(' 00:00:00');
            soqlResult += 'AND Order_Date__c > ' + formatFrom + ' ';
            
        } else if (fromDate == null && toDate != null){
            String formatTo = String.valueOf(toDate).removeEnd(' 00:00:00');
            soqlResult += 'AND Order_Date__c <= ' + formatTo + ' ';
            
        }
        if(Test.isRunningTest()){
            soqlResult += ' limit 1 ';
        }
        finalItems = Database.query(soqlResult);
        
        for (OrderItem item: finalItems){
            //if else statement that populates the Direct Delivery field
            if (item.Direct_Delivery__c == true){
                item.Estimated_Availability__c = 'Direct';
            } else if (item.NATT_Available_Promise_Date__c == null) {
                
                item.Estimated_Availability__c = '0000-00-00 (Estimated)';
            } else {
                item.Estimated_Availability__c = item.NATT_Available_Promise_Date__c.format();
            }
            
            //logic that populates the Total Shipped of Total Ordered field
            String totalShipped = '0';
            String totalOrdered = '0';
            if(item.NATT_Shipped_Quantity__c != null){
                totalShipped = String.valueOf(item.NATT_Shipped_Quantity__c);
            }
            if(item.Quantity != null){
                totalOrdered = String.valueOf(item.Quantity);
                totalOrdered = totalOrdered.remove('.00');
            }
            item.Total_Shipped_of_Total_Ordered__c = (totalShipped + ' of ' + totalOrdered);
            /*if(item.Last_Update__c != null){
System.debug('OrderId: ' + item.OrderId + '|| LastUpdate: ' + item.Last_Update__c.format());
System.debug('Order Value Grab: ' + item.Order.NATT_Last_Update__c);

}*/Map<String, Object> orderMap = new Map<String, Object>();
            // Add the first 10 fields to the map
            //     orderMap.put('Id', item.Id);
            orderMap.put('Order_Date__c', item.Order_Date__c);
            orderMap.put('Order_Number__c', item.Order_Number__c);
            orderMap.put('Purchase_Order_Number__c', item.Purchase_Order_Number__c);
            orderMap.put('Customer__c', item.Customer__c);
            orderMap.put('PartsNet__c', item.PartsNet__c);
            //  orderMap.put('Depot__c', item.Depot__c);
            //     orderMap.put('Order_Type__c', item.Order_Type__c);
            orderMap.put('Parent_Order_Type__c', item.Parent_Order_Type__c);
            orderMap.put('Part_Number__c', item.Part_Number__c);
            orderMap.put('Description__c', item.Description__c);
            orderMap.put('Quantity', item.Quantity);
            orderMap.put('NATT_Shipped_Quantity__c', item.NATT_Shipped_Quantity__c);
            orderMap.put('NATT_Backordered_Quantity__c', item.NATT_Backordered_Quantity__c);
            orderMap.put('Estimated_Availability__c', item.Estimated_Availability__c);
            orderMap.put('NAC_Note__c', item.NAC_Note__c);
            orderMap.put('Total_Shipped_of_Total_Ordered__c', item.Total_Shipped_of_Total_Ordered__c);
            //  orderMap.put('order.NATT_Shipping_Address__r.NATT_JDE_Alpha_Name__c', item.order.NATT_Shipping_Address__r.NATT_JDE_Alpha_Name__c);
            
            result1.add(orderMap);     
            
       
    }
    return result1;
}

//Query a list of Top 20 Backordered Items
@AuraEnabled
// public static List<OrderItem> getTopOrderedItems(String UserId) {
// public static List<AggregateResult> getTopOrderedItems(String UserId) {
public static List<TopBackorderWrapper> getTopOrderedItems(String UserId) {
    System.debug('#####' + ConnectApi.Communities.getCommunities());
    SYstem.debug('## Community ID Network Id: ' + Network.getNetworkId());
    System.debug('UserId: ' + UserId);
    User userRecord = [SELECT ContactId FROM User WHERE Id = :UserId];
    Contact userContact = [SELECT AccountId FROM Contact WHERE Id = :userRecord.ContactId];
    System.debug('AccountId: ' + userContact.AccountId);
    //List <OrderItem> aggList = [SELECT COUNT(Id), NATT_Original_Order__c FROM OrderItem Group By NATT_Original_Order__c ];
    // List <OrderItem> returnValue = [SELECT Description__c, NATT_Unit_Name__c, AvailableQuantity, Quantity, NATT_Backordered_Quantity__c, NATT_Original_Order__c, Part_Number__c FROM OrderItem WHERE NATT_Backordered_Quantity__c > 0 AND  Order.AccountId = :userContact.AccountId ORDER BY NATT_Backordered_Quantity__c desc ];
    List <OrderItem> returnValue = [SELECT Id, NATT_Backordered_Quantity__c, Part_Number__c FROM OrderItem WHERE NATT_Backordered_Quantity__c > 0 AND  Order.AccountId = :userContact.AccountId ORDER BY NATT_Backordered_Quantity__c DESC ];
    List <TopBackorderWrapper> topBackorderedItems = new List <TopBackorderWrapper>();
    
    
    //cycle through and add IDS
    Map<String, TopBackorderWrapper> backorderItemMap = new Map<String,TopBackorderWrapper>();
    for(OrderItem item : returnValue){
        System.debug('Product Id: ' + item.Part_Number__c);
        System.debug('Does it Contain Key: ' + backorderItemMap.containsKey(item.Id));
        if(backorderItemMap.containsKey(item.Part_Number__c)){
            System.debug('Product Already Grabbed');
            System.debug('before wrapper create');
            TopBackorderWrapper updateBackorderItem = backorderItemMap.get(item.Part_Number__c);
            System.debug('before quantity Assign');
            if(item.NATT_Backordered_Quantity__c != null && updateBackorderItem.quantity != null){
                updateBackorderItem.quantity += item.NATT_Backordered_Quantity__c;
            }
            backorderItemMap.put(item.Part_Number__c, updateBackorderItem);
        }else{
            TopBackorderWrapper backItem = new TopBackorderWrapper();
            backItem.Id = item.Id;
            backItem.partNumber = item.Part_Number__c;
            backItem.quantity = item.NATT_Backordered_Quantity__c;
            backorderItemMap.put(item.Part_Number__c,backItem);
        }
    }
    topBackorderedItems.addAll(backorderItemMap.values());
    topBackorderedItems.sort();
    // for(TopBackorderWrapper wrapper :backorderItemMap.values() ){
    //     topBackorderedItems.add(wrapper.TopBackorderWrapper);
    // }
    //if Id already exists, add value to backorder value
    
    // topBackorderedItems.sort();
    SYstem.debug('Length: ' + topBackorderedItems.size());
    List <TopBackorderWrapper> top20 = new List <TopBackorderWrapper>();
    // if(topBackorderedItems.size() > 20){
    for(TopBackorderWrapper item : topBackorderedItems){
        if(top20.size() >= 20){
            break;
        }
        top20.add(item);
    }
    topBackorderedItems = top20;
    // }
    // List <Id> ordItm = new List<Id>();
    // for (OrderItem item : returnValue){
    //     ordItm.add(item.id);
    // }
    // List <AggregateResult> aggList = [SELECT Product2Id, Part_Number__c, NATT_Original_Order__c, SUM(NATT_Backordered_Quantity__c) FROM OrderItem WHERE Id IN :ordItm Group By Product2Id ];
    // List <AggregateResult> aggList = [SELECT COUNT(Id), NATT_Original_Order__c FROM OrderItem WHERE Id IN :ordItm Group By NATT_Original_Order__c ];
    // List <AggregateResult> aggList1 = [SELECT Part_Number__c, SUM(NATT_Backordered_Quantity__c) NATT_Backordered_Quantity__c FROM OrderItem WHERE Id IN :ordItm GROUP BY Part_Number__c ORDER BY SUM(NATT_Backordered_Quantity__c) DESC];
    // return [SELECT Description__c, NATT_Unit_Name__c, AvailableQuantity, Quantity, NATT_Backordered_Quantity__c, NATT_Original_Order__c, Part_Number__c FROM OrderItem WHERE NATT_Backordered_Quantity__c > 0 ORDER BY NATT_Backordered_Quantity__c desc LIMIT 20 ];
    SYstem.debug('NEW Length top20: ' + top20.size());
    return top20;
}

/**
* Gets webstore being accessed. 
* - Webstore determines which columns will get displayed
*/
@AuraEnabled
public static String getWebstore(String communityId){
    String webstoreId = B2BUtils.resolveCommunityIdToWebstoreId(communityId);
    WebStore ws = [SELECT Id,Name FROM WebStore WHERE Id = :webstoreId];
    return ws.Name;
}  
    

}