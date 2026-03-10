@isTest
public class NATT_PriceAvailabilityController_Test {
  private static String email = 'newuser@testorg.com';
  private static String email2 = 'newuser@testorg2.com';

  @testSetup
  private static void testSetup() {
    Pricebook2 standardPB = new Pricebook2(
      Name = 'Standard Price Book',
      IsActive = true
    );

    insert standardPB;

    standardPB.Id = Test.getStandardPricebookId();

    update standardPB;

    Pricebook2 testPB = new Pricebook2(
      Name = 'test pricebook',
      isActive = true
    );

    insert testPB;

    Product2 testProductNEW = new Product2(
      Name = 'Product Test NEW',
      NATT_P_N__c = 'PNtest123NEW',
      NATT_Weight__c = 10,
      Description = 'desc test',
      QuantityUnitOfMeasure = 'Each',
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
      QuantityUnitOfMeasure = 'Each',
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
      QuantityUnitOfMeasure = 'Each',
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

    String username = email + Datetime.now().getTime();

    Account testAcc1 = new Account(
      Name = 'test acc TT',
      NATT_Division__c = 'Truck Trailer',NATT_Organization__c = 'NATT',NATT_Region__c = 'East'
      // ,
      // NATT_Dealership__c = '001P000001nBeCqIAK'
    );

    insert testAcc1;

    Contact testContact = new Contact(
      LastName = 'test c TT',
      NATT_Account_Contact_Role__c = 'President',
      AccountId = testAcc1.Id
    );

    insert testContact;

    Account testAcc2 = new Account(
      Name = 'test acc C',
      NATT_Division__c = 'Container',NATT_Organization__c = 'NATT',NATT_Region__c = 'East'      
    );

    insert testAcc2;

    Contact testContact2 = new Contact(
      LastName = 'test c C',
      NATT_Account_Contact_Role__c = 'President',
      AccountId = testAcc2.Id
    );

    insert testContact2;

    Profile p = [
      SELECT Id
      FROM Profile
      WHERE Name = 'NATT Full Access Community'
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
    NATT_ProductInventoryItem__c result = NATT_PriceAvailabilityController.getAvailable(
      testqtt.NATT_ProductItem__c
    );
      NATT_ProductInventoryItem__c result1 = NATT_PriceAvailabilityController.getCtmAvailablity(
      testqtt.NATT_ProductItem__c,'LATAM'
    );
     

    System.assert(result.NATT_AvailableQuantity__c == 69);
    NATT_PriceAvailabilityController.getQuantityBreakListPrices();
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
    List<Product2> history = NATT_PriceAvailabilityController.getHistory(
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
    List<Product2> history = NATT_PriceAvailabilityController.getHistory(
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
    List<Product2> history = NATT_PriceAvailabilityController.getHistory(
      product.Id
    );
    Test.stopTest();

    System.assertEquals(3, history.size());
    System.assertEquals(product.Id, history[0].Id);
  }
/*
  @isTest
  private static void getUserGuide_testNoGuide() {
    Product2 product = [
      SELECT Id
      FROM Product2
      WHERE Name = 'Product Test'
      LIMIT 1
    ];

    Test.startTest();
    List<ContentDocument> docs = NATT_PriceAvailabilityController.getUserGuide(
      product.Id
    );
    Test.stopTest();

    System.assertEquals(0, docs.size());
  }

  @isTest
  private static void getUserGuide_testHasGuide() {
    Product2 product = [
      SELECT Id
      FROM Product2
      WHERE Name = 'Product Test'
      LIMIT 1
    ];

    ContentVersion contentVersion = new ContentVersion(
      Title = 'a picture',
      PathOnClient = 'Pic.jpg',
      VersionData = Blob.valueOf('Test Content'),
      IsMajorVersion = true
    );
    insert contentVersion;

    List<ContentDocument> documents = [
      SELECT Id, Title, LatestPublishedVersionId
      FROM ContentDocument
    ];

    ContentDocumentLink cdl = new ContentDocumentLink();
    cdl.LinkedEntityId = product.Id;
    cdl.ContentDocumentId = documents[0].Id;
    cdl.ShareType = 'V';
    cdl.Visibility = 'AllUsers';
    insert cdl;

    Test.startTest();
    List<ContentDocument> docs = NATT_PriceAvailabilityController.getUserGuide(
      product.Id
    );
    Test.stopTest();

    System.assertEquals(1, docs.size());
    System.assertEquals(cdl.ContentDocumentId, docs[0].Id);
  }*/

}