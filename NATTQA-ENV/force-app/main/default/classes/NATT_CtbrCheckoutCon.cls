public with sharing class NATT_CtbrCheckoutCon {
        
    @AuraEnabled    
    public static void createRushFeeCartItem(String cartId,String deliveryMethodId,decimal rushFee){
        List<Product2> pList = new List<Product2>([SELECT Id FROM Product2 WHERE Name='Rush Fee']);
        try{
            if(pList.isEmpty() || Test.isRunningTest()){
                Product2 p = new Product2(Name='Rush Fee',IsActive=true);
                insert p;
                pList.add(p);
                Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE IsStandard=true];

                PricebookEntry pbe = new PricebookEntry(Product2Id=p.Id,Pricebook2Id=pb.Id,IsActive=true,UnitPrice=1);
                insert pbe;
            }
            CartDeliveryGroup cdg = [SELECT Id FROM CartDeliveryGroup WHERE CartId =:cartId limit 1];
            CartItem ci = new CartItem(Name='Rush Fee',CartId=cartId,Product2Id=pList.get(0).Id,ListPrice=rushFee,SalesPrice=rushFee,Quantity=1,CartDeliveryGroupId=cdg.Id,Type='Charge', CurrencyIsoCode='USD');
            insert ci;
        }catch(Exception e){
            System.debug('Exception in createRushFeeCartItem:'+e);
            throw new AuraHandledException('Error in NATT_PpgCheckoutCon.createRushFeeCartItem:'+e.getMessage());
        }
    }
}