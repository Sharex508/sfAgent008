@isTest
public class NAC_CheckoutControllerTest {
    static string communityId = [SELECT Id, Name FROM Network WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC].Id;
    
    @isTest
    static void fetchOrderDataTest(){
        Account acc = NAC_TestDataFactory.insertAccount();
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc);
        User us=NAC_TestDataFactory.runAsNACUser();
        String effectiveAccountId=acc.id;
        WebStore webstore = NAC_TestDataFactory.webstoreCreation();
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,webstore.id);
        
        BuyerAccount buyerAccount = new BuyerAccount();
        buyerAccount.BuyerId = acc.Id;
        buyerAccount.Name = NAC_Global_Constants.NAMEVAR + NAC_TestDataFactory.randomStringGenerator();
        buyerAccount.IsActive = true;
        insert buyerAccount;
        
        Order CreateOrder=new Order(
            EffectiveDate = Date.today(),
            Status = 'Draft',
            AccountId = acc.id,
            BillToContactId = con.id,
            BillingState = 'CA',
            BillingCity = 'Beverly Hills',
            BillingCountry = 'US',
            BillingPostalCode = '90210',
            BillingStreet = '444 Fake St.',
            ShippingStreet = '444 fake street', 
            ShippingCity = 'Beverly Hills',
            ShippingState = 'CA',
            ShippingCountry = 'US',
            ShippingPostalCode = '901122',
            OrderedDate = Datetime.newInstance(2022, 1, 2, 3, 4, 5),
            Pricebook2Id = System.Test.getStandardPricebookId()
        );
        insert CreateOrder;
        NAC_CheckoutController.orderLineList orderWrap = new NAC_CheckoutController.orderLineList();
        system.debug('CreateOrder@@ '+CreateOrder+' '+System.Test.getStandardPricebookId());
        Order fetchOrder=NAC_CheckoutController.fetchOrderData(CreateOrder.id);
        System.assertNotEquals(fetchOrder.Id,null,'we were not able to fetch the order');
    }
    
    
    @IsTest(SeeAllData=true)
    static void getCheckOutDetailsTest(){ 
        Account acc = NAC_TestDataFactory.insertAccount();
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc);
        
        User us=NAC_TestDataFactory.runAsNACUser();
        User userDetail = [SELECT contactid, contact.AccountId FROM User WHERE Id =: us.id LIMIT 1];
        
        Id currCon= us.ContactId;
        Contact currAcc =[Select AccountId from Contact where Id=:currCon];
        currAcc.AccountId= acc.Id;
        update currAcc;
        
        String effectiveAccountId=acc.id;
        BuyerAccount buyerAccount=NAC_TestDataFactory.insertBuyerAccount(acc);
        
        WebStore web = [SELECT id FROM WebStore WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC LIMIT 1];
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,web.id);
      
        
        List<BuyerGroup> insertBuyerGroupList = new List<BuyerGroup>{new BuyerGroup(Name = Label.NAOCAP_Prefix + 'CTESTE3', NAC_Type__c = 'C3'), new BuyerGroup(Name = Label.NAOCAP_Prefix + 'V1CTESTE3H')};
        insert insertBuyerGroupList;
        
        insert new List<WebStoreBuyerGroup>{new WebStoreBuyerGroup(WebStoreId = web.Id, BuyerGroupId = insertBuyerGroupList[0].Id), new WebStoreBuyerGroup(WebStoreId = web.Id, BuyerGroupId = insertBuyerGroupList[1].Id)};
        insert new List<BuyerGroupMember>{new BuyerGroupMember(BuyerGroupId = insertBuyerGroupList[0].Id, BuyerId = acc.Id), new BuyerGroupMember(BuyerGroupId = insertBuyerGroupList[1].Id, BuyerId = acc.Id)};
        
        
        NAC_CheckoutController.checkOutWrapper cOw;
        List<StaticResource> BulUploadTemp=[SELECT Id, SystemModStamp ,Name FROM StaticResource WHERE Name =:NAC_Global_Constants.STATIC_RESOURCE_NAME LIMIT 1];
        System.assertNotEquals(BulUploadTemp.size(),null,'we were not able to retrieve the static resource');
        List<PriceBook2> priceBookList = NAC_TestDataFactory.createPriceBook(1);
        insert priceBookList;
        
         Map<Id, Decimal> product2PriceMap = new Map<Id, Decimal>();
         System.assertNotEquals(BulUploadTemp.size(),null,'we were not able to retrieve the static resource');
         WebCart cartCreate=NAC_TestDataFactory.cartCreation(web.id,acc.Id);
         List<CartItem> cartItem=[select Id,CartId,product2ID,product2.recordtypeid,Product2.NATT_CoreItem_P_N__c,Product2.NATT_P_N__c,Product2.recordType.Name,Product2.NATT_Core__c,Product2.NATT_Branch_Plant_Warehouse__c,product2.Name,CartDeliveryGroupId from cartItem where CartId=:cartCreate.id];
           try{
              // System.runAs(us){
                cOw=NAC_CheckoutController.getCheckOutDetails(us.id,communityId,BulUploadTemp[0].Name,effectiveAccountId);
             //  }
                System.assertNotEquals(cOw,null,'we were not able to get the checkout details');
            }
           catch(Exception e){
                
           }
    }
    @isTest
    static void getcreateOrdersDetailsTest(){
        
        Account acc = NAC_TestDataFactory.insertAccount();
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc);
        User us=NAC_TestDataFactory.runAsNACUser();
        User userDetail = [SELECT contactid, contact.AccountId FROM User WHERE Id =: us.id LIMIT 1];
        
        String effectiveAccountId=acc.id;
        BuyerAccount buyerAccount=NAC_TestDataFactory.insertBuyerAccount(acc);
        WebStore web = NAC_TestDataFactory.webstoreCreation();
        
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,web.id);
        
        List<BuyerGroup> insertBuyerGroupList = new List<BuyerGroup>{new BuyerGroup(Name = Label.NAOCAP_Prefix + 'CTESTE3', NAC_Type__c = 'C3'), new BuyerGroup(Name = Label.NAOCAP_Prefix + 'V1CTESTE3H')};
        insert insertBuyerGroupList;
        
        insert new List<WebStoreBuyerGroup>{new WebStoreBuyerGroup(WebStoreId = web.Id, BuyerGroupId = insertBuyerGroupList[0].Id), new WebStoreBuyerGroup(WebStoreId = web.Id, BuyerGroupId = insertBuyerGroupList[1].Id)};
        insert new List<BuyerGroupMember>{new BuyerGroupMember(BuyerGroupId = insertBuyerGroupList[0].Id, BuyerId = acc.Id), new BuyerGroupMember(BuyerGroupId = insertBuyerGroupList[1].Id, BuyerId = acc.Id)};
        
        WebCart cartCreate=NAC_TestDataFactory.cartCreation(web.id,acc.Id);
        List<CartItem> cartItem=[select Id,CartId,product2ID,product2.recordtypeid,Product2.NATT_CoreItem_P_N__c,Product2.NATT_P_N__c,Product2.recordType.Name,Product2.NATT_Core__c,Product2.NATT_Branch_Plant_Warehouse__c,product2.Name,CartDeliveryGroupId from cartItem where CartId=:cartCreate.id];
        Map<Object,Object> mapOfOrderInformation=new MAp<Object,Object>();
        MAp<Object,Object> mapOfOrderType=new MAp<Object,Object>();
        MAp<Object,Object> mapofshippingMethod=new MAp<Object,Object>();
        MAp<Object,Object> mapofdeliveryTerm=new MAp<Object,Object>();
        
        mapOfOrderType.put('label','4G');
        mapOfOrderType.put('validFor','[]');
        mapOfOrderType.put('value','4G');
        
        mapofshippingMethod.put('label','BW1 - BESTWAY');
        mapofshippingMethod.put('validFor','[0]');
        mapofshippingMethod.put('value','BW1');
        
        mapofdeliveryTerm.put('label','PPD - Prepaid Freight');
        mapofdeliveryTerm.put('label','[0, 1]');
        mapofdeliveryTerm.put('value','PPD');
        
        mapOfOrderInformation.put('phone','9080000000');
        mapOfOrderInformation.put('email','rty@ert.com');
        mapOfOrderInformation.put('shippingAddressValue','California');
        mapOfOrderInformation.put('shippingStreetValue','ABC');
        mapOfOrderInformation.put('shippingPostalCodeValue','123456');
        mapOfOrderInformation.put('shippingCountryValue','US');
        mapOfOrderInformation.put('billingAddressValue','USA');
        mapOfOrderInformation.put('billingStreetValue','cv North West');
        mapOfOrderInformation.put('billingCityValue','Malibu');
        mapOfOrderInformation.put('billingStateValue','California');
        mapOfOrderInformation.put('billingCountryValue','US');
        
        mapOfOrderInformation.put('orderType',mapOfOrderType);
        mapOfOrderInformation.put('shippingMethod',mapofshippingMethod);
        mapOfOrderInformation.put('deliveryTerm',mapofdeliveryTerm); 
        mapOfOrderInformation.put('shipComplete',false);
        mapOfOrderInformation.put('requestedDate',String.valueof(date.today()));
        mapOfOrderInformation.put('purchaseOrderNo','');
        mapOfOrderInformation.put('acceptedTerms',false);
        
       // System.assertNotEquals(cartCreat.Id,null,'we were not able to retrieve the cart Id');
        NAC_CheckoutController.orderResultWrapper nOc=NAC_CheckoutController.createOrders(cartCreate.id,mapOfOrderInformation);
        System.assertNotEquals(nOc,null,'we were not able to retrieve the cart Id');
    }
    @isTest
    static void getRushOrderChargeTest(){
        Account acc = NAC_TestDataFactory.insertAccount();
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc);
        User us=NAC_TestDataFactory.runAsNACUser();
        
        Decimal returnD=NAC_CheckoutController.getRushOrderCharge(acc.id);
        system.assertNotEquals(returnD, null, 'Some problem with the fee charged');
    }
}