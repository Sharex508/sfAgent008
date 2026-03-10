public with sharing class CTM_BackorderReportHelper {

    // ---------- Wrapper & sorting ----------
    public class TopBackorderWrapper implements Comparable {
        @AuraEnabled public String Id {get;set;}
        @AuraEnabled public String partNumber {get;set;}
        @AuraEnabled public Decimal quantity {get;set;}

        // Sort DESC by quantity
        public Integer compareTo(Object recordToCompare){
            TopBackorderWrapper other = (TopBackorderWrapper)recordToCompare;
            if (this.quantity == other.quantity) return 0;
            return (this.quantity > other.quantity) ? -1 : 1;
        }
    }

    // ---------- Private helpers ----------
    private static Id currentUserId() { return UserInfo.getUserId(); }

    private static Id currentAccountId() {
        User u = [
            SELECT ContactId, Contact.AccountId
            FROM User WHERE Id = :UserInfo.getUserId()
        ];
        return (u.ContactId != null) ? u.Contact.AccountId : null;
    }

    private static String escapeLike(String s) {
        if (s == null) return null;
        s = s.trim();
        if (s == '') return null;
        return '%' + String.escapeSingleQuotes(s) + '%';
    }

    private static Map<String, Object> toRow(OrderItem item) {
        // Estimated_Availability__c presentation
        if (item.Direct_Delivery__c == true){
            item.Estimated_Availability__c = 'Direct';
        } else if (item.NATT_Available_Promise_Date__c == null) {
            item.Estimated_Availability__c = '0000-00-00 (Estimated)';
        } else if (Date.today().daysBetween(item.NATT_Available_Promise_Date__c) > 45){
            item.Estimated_Availability__c = 'Call for availability';
        } else {
            item.Estimated_Availability__c = String.valueOf(item.NATT_Available_Promise_Date__c);
        }

        // Total Shipped of Total Ordered
        String totalShipped = (item.NATT_Shipped_Quantity__c != null) ? String.valueOf(item.NATT_Shipped_Quantity__c) : '0';
        String totalOrdered = (item.Quantity != null) ? String.valueOf(item.Quantity).remove('.00') : '0';
        item.Total_Shipped_of_Total_Ordered__c = totalShipped + ' of ' + totalOrdered;

        Map<String, Object> row = new Map<String, Object>();
        row.put('Id', item.Id); // needed for datatable keyField & navigateToSObject
        row.put('Order_Date__c', item.Order_Date__c);
        row.put('Order_Number__c', item.Order_Number__c);
        row.put('Purchase_Order_Number__c', item.Purchase_Order_Number__c);
        row.put('Customer__c', item.Customer__c);
        row.put('PartsNet__c', item.PartsNet__c);
        row.put('Parent_Order_Type__c', item.Parent_Order_Type__c);
        row.put('Part_Number__c', item.Part_Number__c);
        row.put('Description__c', item.Description__c);
        row.put('Quantity', item.Quantity);
        row.put('NATT_Shipped_Quantity__c', item.NATT_Shipped_Quantity__c);
        row.put('NATT_Backordered_Quantity__c', item.NATT_Backordered_Quantity__c);
        row.put('Estimated_Availability__c', item.Estimated_Availability__c);
        row.put('Total_Shipped_of_Total_Ordered__c', item.Total_Shipped_of_Total_Ordered__c);
        return row;
    }

    // ---------- Base select ----------
    private static String baseSelect() {
        return
        'SELECT Id, Order_Date__c, Order_Number__c, Purchase_Order_Number__c, Customer__c, PartsNet__c, Depot__c, ' +
        '       Parent_Order_Type__c, Part_Number__c, Description__c, Quantity, NATT_Shipped_Quantity__c, ' +
        '       NATT_Backordered_Quantity__c, Estimated_Availability__c, Total_Shipped_of_Total_Ordered__c, ' +
        '       Order.NATT_Shipping_Address__r.NATT_JDE_Alpha_Name__c, ' +
        '       OrderItem.Direct_Delivery__c, OrderItem.NATT_Available_Promise_Date__c ' +
        'FROM OrderItem ' +
       
'WHERE NATT_Backordered_Quantity__c != null AND NATT_Backordered_Quantity__c > 0 ' +
    '  AND Order.RecordType.Name = \'CTM Parts Order\'';

        // If your org uses DeveloperName, change the last line to:
        // "  AND Order.RecordType.DeveloperName ='tes'";
    }

    // ---------- Public Aura methods ----------

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getOrderList() {
        List<Map<String, Object>> result = new List<Map<String, Object>>();

        Id acctId = currentAccountId();
        Id uid    = currentUserId();

        String soql = baseSelect();
        if (acctId != null) {
            soql += ' AND Order.AccountId = :acctId';
        } else {
            soql += ' AND Order.OwnerId = :uid';
        }

        if (Test.isRunningTest()) {
            soql += ' ORDER BY Order_Date__c DESC LIMIT 1 ';
        } else {
            soql += ' ORDER BY Order_Date__c DESC LIMIT 2000 ';
        }

        List<OrderItem> items = Database.query(soql);
        for (OrderItem oi : items) result.add(toRow(oi));
        return result;
    }

    @AuraEnabled
    public static List<Map<String, Object>> getResults(String orderNumber, String poNumber, String partNumber, Date fromDate, Date toDate) {
        List<Map<String, Object>> out = new List<Map<String, Object>>();

        Id acctId = currentAccountId();
        Id uid    = currentUserId();

        String soql = baseSelect();
        if (acctId != null) {
            soql += ' AND Order.AccountId = :acctId';
        } else {
            soql += ' AND Order.OwnerId = :uid';
        }

        String orderLike = escapeLike(orderNumber);
        String poLike    = escapeLike(poNumber);
        String partLike  = escapeLike(partNumber);

        if (orderLike != null) soql += ' AND Order_Number__c LIKE :orderLike';
        if (poLike    != null) soql += ' AND Purchase_Order_Number__c LIKE :poLike';
        if (partLike  != null) soql += ' AND Part_Number__c LIKE :partLike';

        if (fromDate != null) soql += ' AND Order_Date__c >= :fromDate';
        if (toDate   != null) soql += ' AND Order_Date__c <= :toDate';

        if (Test.isRunningTest()) {
            soql += ' ORDER BY Order_Date__c DESC LIMIT 1';
        } else {
            soql += ' ORDER BY Order_Date__c DESC LIMIT 2000 ';
        }

        List<OrderItem> finalItems = Database.query(soql);
        for (OrderItem oi : finalItems) out.add(toRow(oi));
        return out;
    }

    @AuraEnabled
    public static List<TopBackorderWrapper> getTopOrderedItems(String UserId) {
        System.debug('UserId: ' + UserId);

        User userRecord = [SELECT Id, Name, ContactId, Profile.Name FROM User WHERE Id = :UserId];
        List<OrderItem> returnValue;

        if ((userRecord.ContactId == null) && userRecord.Profile.Name == 'NATT PPG B2B Admin' ){
            returnValue = [
                SELECT Id, NATT_Backordered_Quantity__c, Part_Number__c
                FROM OrderItem
                WHERE NATT_Backordered_Quantity__c > 0
                  AND Order.RecordType.Name ='CTM Parts Order'
                  AND Order.Account.Name = 'PPG Product Development'
                ORDER BY NATT_Backordered_Quantity__c DESC
            ];
        } else {
            Contact userContact = [SELECT AccountId FROM Contact WHERE Id = :userRecord.ContactId];
            returnValue = [
                SELECT Id, NATT_Backordered_Quantity__c, Part_Number__c
                FROM OrderItem
                WHERE NATT_Backordered_Quantity__c > 0
                  AND Order.RecordType.Name ='CTM Parts Order'
                  AND Order.AccountId = :userContact.AccountId
                ORDER BY NATT_Backordered_Quantity__c DESC 
            ];
        }

        Map<String, TopBackorderWrapper> backorderItemMap = new Map<String, TopBackorderWrapper>();
        for (OrderItem item : returnValue) {
            String key = item.Part_Number__c;
            if (String.isBlank(key)) continue;

            if (backorderItemMap.containsKey(key)){
                TopBackorderWrapper updateBackorderItem = backorderItemMap.get(key);
                Decimal addQty = (item.NATT_Backordered_Quantity__c == null) ? 0 : item.NATT_Backordered_Quantity__c;
                updateBackorderItem.quantity = (updateBackorderItem.quantity == null ? 0 : updateBackorderItem.quantity) + addQty;
                backorderItemMap.put(key, updateBackorderItem);
            } else {
                TopBackorderWrapper backItem = new TopBackorderWrapper();
                backItem.Id = item.Id;
                backItem.partNumber = key;
                backItem.quantity = (item.NATT_Backordered_Quantity__c == null) ? 0 : item.NATT_Backordered_Quantity__c;
                backorderItemMap.put(key, backItem);
            }
        }

        List<TopBackorderWrapper> topBackorderedItems = new List<TopBackorderWrapper>();
        topBackorderedItems.addAll(backorderItemMap.values());
        topBackorderedItems.sort();

        
        Integer n = Math.min(20, topBackorderedItems.size());
        List<TopBackorderWrapper> top20 = new List<TopBackorderWrapper>();
        for (Integer i = 0; i < n; i++) {
            top20.add(topBackorderedItems[i]);
        }
        return top20;

    }

    @AuraEnabled
    public static String getWebstore(String communityId){
        String webstoreId = B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        WebStore ws = [SELECT Id,Name FROM WebStore WHERE Id = :webstoreId];
        return ws.Name;
    }
}