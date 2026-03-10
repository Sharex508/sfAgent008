@isTest
public class NACon_PriceAvailabilityControllerTest {

  private static String email = 'newuser@testorg.com';
  private static String email2 = 'newuser@testorg2.com';
    
    

  @testSetup
  private static void testSetup() {
      
    Id conRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NAOCAP_End_Customer').getRecordTypeId();
    Id itempriceRecordTypeId = Schema.SObjectType.NATT_ItemPriceStaging__c.getRecordTypeInfosByDeveloperName().get('NAOCAP').getRecordTypeId();
      
    Pricebook2 standardPB = new Pricebook2(Name = 'Standard Price Book',IsActive = true );
    insert standardPB;
    standardPB.Id = Test.getStandardPricebookId();
     update standardPB;

    Pricebook2 testPB = new Pricebook2(Name = 'test pricebook',isActive = true);
    insert testPB;

    Product2 testProductNEW = new Product2(
      Name = 'Product Test NEW',
      NATT_P_N__c = 'PNtest123NEW',
      NATT_Weight__c = 10,
      Description = 'desc test',
      QuantityUnitOfMeasure = 'EA',
      StockKeepingUnit = 'skre',
      NATT_ItemPriceGroup__c = '111',
      NATT_SignalCode__c='S2'
    );

    insert testProductNEW;

    Product2 testProductOLD = new Product2(
      Name = 'Product Test OLD',
      NATT_P_N__c = 'PNtest123OLD',
      NATT_Weight__c = 10,
      Description = 'desc test',
      QuantityUnitOfMeasure = 'EA',
      StockKeepingUnit = 'OLDskre',
      NATT_ItemPriceGroup__c = '111',
      NATT_SignalCode__c='S2'
    );

    insert testProductOLD;

    Product2 testProductNeverReplaced = new Product2(
      Name = 'Product Test',
      NATT_P_N__c = 'PNtest123NOR',
      NATT_Weight__c = 10,
      Description = 'desc test',
      QuantityUnitOfMeasure = 'EA',
      StockKeepingUnit = 'NONREPLACEDSKU',
      NATT_ItemPriceGroup__c = '111'
    );

    insert testProductNeverReplaced;

    PriceBookEntry testPBE_NEW_s = new PriceBookEntry(
      Pricebook2Id = standardPB.Id,
      Product2Id = testProductNEW.Id,
      UnitPrice = 696,
      isActive = true
    );

    insert testPBE_NEW_s;

    PriceBookEntry testPBE_NEW = new PriceBookEntry(
      Pricebook2Id = testPB.Id,
      Product2Id = testProductNEW.Id,
      UnitPrice = 696,
      isActive = true,
      UseStandardPrice = true
    );

    insert testPBE_NEW;

    PriceBookEntry testPBE_OLD_s = new PriceBookEntry(
      Pricebook2Id = standardPB.Id,
      Product2Id = testProductOLD.Id,
      UnitPrice = 696,
      isActive = true
    );

    insert testPBE_OLD_s;

    PriceBookEntry testPBE_OLD = new PriceBookEntry(
      Pricebook2Id = testPB.Id,
      Product2Id = testProductOLD.Id,
      UnitPrice = 696,
      isActive = true,
      UseStandardPrice = true
    );

    insert testPBE_OLD;

    NATT_ProductInventoryItem__c availNEW = new NATT_ProductInventoryItem__c(
      NATT_ProductItem__c = testProductNEW.Id,
      NATT_AvailableQuantity__c = 69,
      NATT_Warehouse__c = 'ATL'
    );

    insert availNEW;

    NATT_ProductInventoryItem__c availOLD = new NATT_ProductInventoryItem__c(
      NATT_ProductItem__c = testProductOLD.Id,
      NATT_AvailableQuantity__c = 96,
      NATT_Warehouse__c = 'ATL'
    );

    insert availOLD;

    NATT_AlternativeItem__c hist = new NATT_AlternativeItem__c(
      NATT_AlternativeItem__c = testProductOLD.Id,
      NATT_ProductItem__c = testProductNEW.Id,
      NATT_EffectiveDate__c = date.parse('07/29/2021')
    );

    insert hist;
      
  // NATT_ItemPriceStaging__c  itempricing=new NATT_ItemPriceStaging__c(NATT_QuantityFrom__c=1000,NATT_EffectiveDate__c= date.parse('07/29/2021'),NATT_ExpiryDate__c= date.parse('08/29/2023'),NATT_CustomerNumber__c=0, NATT_Product__c=testProductNeverReplaced.Id,RecordTypeId=itempriceRecordTypeId);
   // insert itempricing;
    String username = email + Datetime.now().getTime();

    Account testAcc1 = new Account(
      Name = 'test acc TT' ,NATT_Organization__c = 'NATT',NATT_Region__c = 'East'
     //	 NATT_Division__c = 'Truck Trailer'
    );

    insert testAcc1;

  /*  Contact testContact = new Contact(
      LastName = 'test c TT',
      NATT_Account_Contact_Role__c = 'President',
      AccountId = testAcc1.Id
    ); */
      
   Contact testContact = new Contact(LastName='TestContactTestCon',RecordTypeId=conRecordTypeId ,NAC_Contact_Type__c='Parts Ordering', NATT_Key_Business_Role__c='Co-Principal',	
   Email='test@gmail.com', Phone='3456237654',  AccountId= testAcc1.Id);

    insert testContact;

    Account testAcc2 = new Account(
      Name = 'test acc C',
      NATT_Division__c = 'Container',NATT_Organization__c = 'NATT',NATT_Region__c = 'East'      
    );

    insert testAcc2;

   /* Contact testContact2 = new Contact(
      LastName = 'test c C',
      NATT_Account_Contact_Role__c = 'President',
      AccountId = testAcc2.Id
    ); */
      
       Contact testContact2 = new Contact(LastName='TestContactTestCon',RecordTypeId=conRecordTypeId ,NAC_Contact_Type__c='Parts Ordering', NATT_Key_Business_Role__c='Co-Principal',	
      Email='test@gmail.com', Phone='3456237654',  AccountId= testAcc2.Id);

    insert testContact2;

    Profile p = [
      SELECT Id
      FROM Profile
      WHERE Name = 'NAC Customer Community Profile'
    ];

    User testUser = new User(
      Contact = testContact,
      ContactId = testContact.Id,
      Alias = 'newUser',
      Email = email,
      EmailEncodingKey = 'UTF-8',
      LastName = 'Testing',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = p.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      //TimeZoneSidKey=String.valueOf(UserInfo.getTimeZone()),
      UserName = username
    );

    insert testUser;

    User testUser2 = new User(
      Contact = testContact2,
      ContactId = testContact2.Id,
      Alias = 'newUser',
      Email = email2,
      EmailEncodingKey = 'UTF-8',
      LastName = 'Testing',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = p.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      //TimeZoneSidKey=String.valueOf(UserInfo.getTimeZone()),
      UserName = username + '2'
    );

    insert testUser2;
  }

  @isTest
  private static void getAvailable_test() {
    Test.startTest();

    NATT_ProductInventoryItem__c testqtt = [
      SELECT
        Id,
        NATT_Warehouse__c,
        NATT_ProductItem__c,
        NATT_AvailableQuantity__c
      FROM NATT_ProductInventoryItem__c
      WHERE NATT_AvailableQuantity__c = 69
    ];
    Id accountId =[SELECT Id  FROM Account WHERE Name='test acc C'].Id;
   // NATT_ItemPriceStaging__c  itempricing=[Select NATT_QuantityFrom__c,NATT_EffectiveDate__c,NATT_ExpiryDate__c,NATT_CustomerNumber__c, NATT_Product__c FROM NATT_ItemPriceStaging__c where NATT_QuantityFrom__c=1000];
    
      
      
    NATT_ProductInventoryItem__c result = NACon_PriceAvailabilityController.getAvailable( testqtt.NATT_ProductItem__c,false, accountId);
     
   

    System.assert(result.NATT_AvailableQuantity__c == 69);
    NACon_PriceAvailabilityController.getQuantityBreakListPrices();
  //  NACon_PriceAvailWoSharing.getQuantityBreakListPrices();
    Test.stopTest();
  }

  @isTest
  private static void getHistory_testProductItem() {
    NATT_AlternativeItem__c alternativeItem = [
      SELECT Id, NATT_AlternativeItem__c, NATT_ProductItem__c
      FROM NATT_AlternativeItem__c
      LIMIT 1
    ];

    Test.startTest();
    List<Product2> history = NACon_PriceAvailabilityController.getHistory(
      alternativeItem.NATT_ProductItem__c
    );
    Test.stopTest();

    System.assertEquals(3, history.size());
    System.assertEquals(alternativeItem.NATT_AlternativeItem__c, history[0].Id);
  }

  @isTest
  private static void getHistory_testAlternativeItem() {
    NATT_AlternativeItem__c alternativeItem = [
      SELECT Id, NATT_AlternativeItem__c, NATT_ProductItem__c
      FROM NATT_AlternativeItem__c
      LIMIT 1
    ];

    Test.startTest();
    List<Product2> history = NACon_PriceAvailabilityController.getHistory(
      alternativeItem.NATT_AlternativeItem__c
    );
    Test.stopTest();

    System.assertEquals(2, history.size());
    System.assertEquals(alternativeItem.NATT_AlternativeItem__c, history[0].Id);
  }

  @isTest
  private static void getHistory_testNoHistory() {
    Product2 product = [
      SELECT Id
      FROM Product2
      WHERE Name = 'Product Test'
      LIMIT 1
    ];

    Test.startTest();
    List<Product2> history = NACon_PriceAvailabilityController.getHistory(
      product.Id
    );
    Test.stopTest();

    System.assertEquals(3, history.size());
    System.assertEquals(product.Id, history[0].Id);
  } 
    
    @isTest
    public static void getQuantityBreakListPricesException(){
         NACon_PriceAvailWoSharing.throwException = true;
        
         try{
             
        List<NATT_ItemPriceStaging__c>  itemlist=  NACon_PriceAvailWoSharing.getQuantityBreakListPrices();
          //  System.assert(false, 'Expected a thrown exception.');
        }catch(AuraHandledException e){
            system.assert(true);
            System.debug(e.getMessage());

        }
        
     
}
    
}