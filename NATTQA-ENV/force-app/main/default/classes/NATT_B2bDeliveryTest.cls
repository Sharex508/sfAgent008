@IsTest
private class NATT_B2bDeliveryTest {
	@IsTest
    static void validTest(){        
        Account a = new Account(Name='TestAccount');
        insert a;
        Contact contact = new Contact(LastName='TestContact', AccountId=a.Id);
        insert contact;
        
        BuyerAccount buyerAccount = new BuyerAccount();
        buyerAccount.BuyerId = a.Id;
        buyerAccount.Name = 'Test Buyer Account (BA-AJ)';
        buyerAccount.IsActive = true;
        insert buyerAccount;

        WebStore webStore = new WebStore(Name='Performance Parts');
		insert webstore;
        
        WebCart cart = new WebCart(Name='Cart', WebStoreId=webStore.Id, AccountId=a.Id);
        insert cart;
        
        CartDeliveryGroup cartDeliveryGroup = new CartDeliveryGroup(CartId=cart.Id, Name='Default Delivery');
        insert cartDeliveryGroup;
        
        NATT_B2bDelivery.SyncDeliveryActionRequest ar = new NATT_B2bDelivery.SyncDeliveryActionRequest();
        ar.cartId=cart.Id;
        ar.orderType='1';
        
        NATT_B2bDelivery.syncDelivery(new List<NATT_B2bDelivery.SyncDeliveryActionRequest>{ar});        
    }
    
    @IsTest
    static void testNoCart(){        
        
        NATT_B2bDelivery.SyncDeliveryActionRequest ar = new NATT_B2bDelivery.SyncDeliveryActionRequest();
        ar.cartId='';
        ar.orderType='1';
        try{
        	NATT_B2bDelivery.syncDelivery(new List<NATT_B2bDelivery.SyncDeliveryActionRequest>{ar});        
        }catch(Exception e){
            
        }
    }
    
    @IsTest
    static void testNoCartDeliveryGroup(){        
        Account a = new Account(Name='TestAccount');
        insert a;
        Contact contact = new Contact(LastName='TestContact', AccountId=a.Id);
        insert contact;
        
        BuyerAccount buyerAccount = new BuyerAccount();
        buyerAccount.BuyerId = a.Id;
        buyerAccount.Name = 'Test Buyer Account (BA-AJ)';
        buyerAccount.IsActive = true;
        insert buyerAccount;

        WebStore webStore = new WebStore(Name='Performance Parts');
		insert webstore;
        
        WebCart cart = new WebCart(Name='Cart', WebStoreId=webStore.Id, AccountId=a.Id);
        insert cart;
        
        NATT_B2bDelivery.SyncDeliveryActionRequest ar = new NATT_B2bDelivery.SyncDeliveryActionRequest();
        ar.cartId=cart.Id;
        ar.orderType='1';
        try{
        	NATT_B2bDelivery.syncDelivery(new List<NATT_B2bDelivery.SyncDeliveryActionRequest>{ar});        
        }catch(Exception e){
            
        }
    }
    
    @TestSetup
    static void makeData(){
        Id rtId = [SELECT Id FROM RecordType WHERE SobjectType='NATT_B2B_Shipping_Option__c' AND DeveloperName='NATT_Shipment'].Id;
        
        List<NATT_B2B_Shipping_Option__c> soList = new List<NATT_B2B_Shipping_Option__c>();
        soList.add(new NATT_B2B_Shipping_Option__c(Name='BW1 - BESTWAY',RecordTypeId=rtId,
                                                                         NATT_Order_Type__c='2;4;1',NATT_Shipping_Method__c='BW1'));
        
        soList.add(new NATT_B2B_Shipping_Option__c(Name='CR1 - CUSTOMER ROUTING',RecordTypeId=rtId,
                                                                         NATT_Order_Type__c='2;1',NATT_Shipping_Method__c='CR1'));
        
        soList.add(new NATT_B2B_Shipping_Option__c(Name='FX1 - FEDEX - NEXT DAY AIR',RecordTypeId=rtId,
                                                                         NATT_Order_Type__c='2;1',NATT_Shipping_Method__c='FX1'));
        
        soList.add(new NATT_B2B_Shipping_Option__c(Name='FX2 - FEDEX - 2ND DAY AIR',RecordTypeId=rtId,
                                                                         NATT_Order_Type__c='2;1',NATT_Shipping_Method__c='FX2'));
        
        soList.add(new NATT_B2B_Shipping_Option__c(Name='FX3 - FEDEX - 3RD DAY AIR',RecordTypeId=rtId,
                                                                         NATT_Order_Type__c='2;1',NATT_Shipping_Method__c='FX3'));
        
        soList.add(new NATT_B2B_Shipping_Option__c(Name='FXG - FEDEX - GROUND',RecordTypeId=rtId,
                                                                         NATT_Order_Type__c='2;1',NATT_Shipping_Method__c='FXG'));
        
        soList.add(new NATT_B2B_Shipping_Option__c(Name='OF - OCEAN FREIGHT',RecordTypeId=rtId,
                                                                         NATT_Order_Type__c='2;1',NATT_Shipping_Method__c='OF'));
        
        soList.add(new NATT_B2B_Shipping_Option__c(Name='AF - AIR FREIGHT',RecordTypeId=rtId,
                                                                         NATT_Order_Type__c='2;1',NATT_Shipping_Method__c='AF'));
        
        insert soList;
    }
}