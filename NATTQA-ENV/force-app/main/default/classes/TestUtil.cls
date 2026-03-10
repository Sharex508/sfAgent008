public class TestUtil {

    public static Product2 createProduct(String pName,String pCode){
        
        return new Product2(Name = pName,
                            ProductCode = pCode,
                            IsActive = true);
    }
    
    public static Order createOrder(Account acc,Date startDate,String status){
        
        return new Order(AccountId = acc.Id,EffectiveDate = Date.today(),Status = status);
    }
    
    public static OrderItem createOrderItem(Product2 product,Integer qty,Order odr,Integer gpLine,Boolean hasBaseUnit){
        
        return new OrderItem(Product2Id = product.Id,
                             ListPrice = 100,
                             UnitPrice = 100,
                             SBQQ__QuotedListPrice__c = 100,
                             NATT_End_Customer_Price__c = 150,
                             Quantity = qty,
                             OrderId = odr.Id,
                             NATT_Grouped_By_Line_Number__c = gpLine,
                             SBQQ__QuotedQuantity__c = qty,
                             NATT_Current_Effective_Quantity__c = 1,
                             NATT_Is_Base_Unit__c = hasBaseUnit,
                             NATT_Original_Order_Id__c = odr.NATT_Original_Order_Id__c);
    }
    
    public static Asset createAsset(Product2 product,String assetName,String odrId,Account acc){
        
        return new Asset(Name = assetName,
                         ContactId = null,
                         Product2Id = product.Id,
                         AccountId = acc.Id,
                         NATT_Original_Order_Id__c = odrId,
                         NATT_Hide_Asset__c = true);
    }
    
    public static SBQQ__LookupData__c createLookupData(String product,Date startDate,Date endDate,String type){
        
        return new SBQQ__LookupData__c(SBQQ__Product__c = product,
                                       NATT_Start_Date__c = startDate,
                                       NATT_End_Date__c = endDate,
                                       SBQQ__Type__c = type);
    }
    
    // Public method to create Price Book Entry record for testing.    
    public static PriceBookEntry createPriceBookEntry(String priceBookId, String productId){
        PriceBookEntry priceBookEntryRecord = new PriceBookEntry();
        priceBookEntryRecord.Pricebook2Id = priceBookId; 
        priceBookEntryRecord.Product2Id = productId;
        priceBookEntryRecord.IsActive = true;
        priceBookEntryRecord.UnitPrice = 100;
        return priceBookEntryRecord;
    } 
    
    public static SBQQ__QuoteLine__c createQuoteLine(String productId, String quoteId){
        SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c();
        quoteLine.SBQQ__Product__c = productId; 
        quoteLine.SBQQ__Quote__c = quoteId;
        quoteLine.SBQQ__Quantity__c = 1;
        quoteLine.SBQQ__StartDate__c = System.today() + 30;
        return quoteLine;
    }
}