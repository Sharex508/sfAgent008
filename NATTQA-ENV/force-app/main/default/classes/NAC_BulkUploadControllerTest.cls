@isTest
public class NAC_BulkUploadControllerTest {
    
    static string communityId = [SELECT Id, Name FROM Network WHERE Name =: NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC].Id;
    
    @istest
    static void GetResourceURL_Positive_Test(){
        string urlPath = NAC_BulkUploadController.GetResourceURL(NAC_Global_Constants.STATIC_RESOURCE_NAME);
        system.assert(urlPath.contains('/resource/'));
    }
    
    @istest
    static void GetResourceURL_Negative_Test(){
        string urlPath = NAC_BulkUploadController.GetResourceURL('RANDOM_TEXT_NAME');
        system.assertEquals('', urlPath);
    }
    
    private static returnData createData(Boolean createStore){
        returnData data = new returnData();
        Id prodRecordTypeId = Schema.SObjectType.Product2.getRecordTypeInfosByDeveloperName().get('NAC_Products').getRecordTypeId();
        Map<Id, Decimal> product2PriceMap = new Map<Id, Decimal>();
        List<Id> product2IdList = new List<Id>();
        WebStore web;
        if(createStore){
            web = [SELECT id FROM WebStore WHERE Name =: NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC LIMIT 1];
        }else{
            web = NAC_TestDataFactory.webstoreCreation();
        }
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,web.id);
        ProductCategory pc = NAC_TestDataFactory.createProductCategory(web.Id);
        List<Product2> product2List = NAC_TestDataFactory.createProductList(5);
        for(integer i = 0; i < product2List.size(); i++){
            product2List[i].RecordTypeId = prodRecordTypeId;
            product2List[i].NATT_SignalCode__c = 'A';
            product2List[i].NATT_Sales_Code__c = 'S01';
            if(i == 1){
                product2List[i].NATT_SignalCode__c = 'S2';
                product2List[i].NATT_CoreItem_P_N__c = product2List[i+3].ProductCode;
            }
            if(i == 2){
                product2List[i].NATT_SignalCode__c = 'PRC';
            }
            if(i == 3){
                product2List[i].NATT_SignalCode__c = 'S2';
            }
            if(i == 4){ 
                 product2List[i].NATT_Core__c = true;
            }
            product2List[i].NATT_ItemPriceGroup__c = '510';
            product2List[i].NAOCAP_Under_Processing__c = true;
            product2List[i].NATT_Branch_Plant_Warehouse__c = 'ATL';
            product2List[i].NATT_P_N__c = product2List[i].ProductCode;
            product2List[i].NATT_UnitCost__c = 1718;
        }
        insert product2List;
        List<NATT_AlternativeItem__c> altItemList = new List<NATT_AlternativeItem__c>();
        for(integer i = 0; i < product2List.size(); i++){
            product2IdList.add(product2List[i].Id);
            if(i != product2List.size() - 1){
                product2PriceMap.put(product2List[i].Id, Math.random() * 100);
                if(i == 1 || i == 3){
                    NATT_AlternativeItem__c altItem = new NATT_AlternativeItem__c();
                    altItem.NATT_AlternativeItem__c = product2List[i-1].Id;
                    altItem.NATT_ProductItem__c = product2List[i].Id;
                    altItem.NATT_EffectiveDate__c = System.today() - 365;
                    altItem.NATT_ExpiryDate__c = System.today() + 365;
                    altItemList.add(altItem);
                }
            }
        }        
        insert altItemList;
        NAC_TestDataFactory.createProductCategoryProductList(new Map<Id,List<Id>>{pc.Id => product2IdList});
        data.usr = NAC_TestDataFactory.runAsNACUser();
        Contact cont = [SELECT Id, AccountId FROM Contact WHERE Id =: data.usr.ContactId];
        data.acc = [SELECT Id FROM Account WHERE Id =: cont.AccountId];
        NAC_TestDataFactory.insertBuyerAccount(data.acc);
        BuyerGroup bg =  NAC_TestDataFactory.insertBuyerGroup();
        WebStoreBuyerGroup wbg =  NAC_TestDataFactory.insertWebStoreBuyerGroup(web, bg);
        NAC_TestDataFactory.insertBuyerGroupMember(data.acc, bg);
        List<PriceBook2> priceBookList = NAC_TestDataFactory.createPriceBook(1);
        insert priceBookList;
        NAC_TestDataFactory.createPriceBookEntry(new Map<Id, Map<Id,Decimal>>{priceBookList[0].Id => product2PriceMap});
        NAC_TestDataFactory.createBuyerGroupPricebook(new Map<Id,List<Id>>{bg.Id => new List<Id>{priceBookList[0].Id}});
        List<CommerceEntitlementPolicy> cepList = NAC_TestDataFactory.createCommerceEntitlementPolicy(1);
        insert cepList;
        NAC_TestDataFactory.createCommerceEntitlementBuyerGroup(new Map<Id,List<Id>>{cepList[0].Id => new List<Id>{bg.Id}});
        NAC_TestDataFactory.createCommerceEntitlementProduct(new Map<Id,List<Id>>{cepList[0].Id => product2IdList});
        return data;
    }
    
    @istest()
    static void readUploadedFile_Test(){
        returnData data = createData(false);
        NAC_BulkUploadController.bulkUploadProductWrapper bulkProdWrap_ATL_Product_Test, bulkProdWrap_ANA_Product_Test, bulkProdWrap_PAN_Product_Test, bulkProdWrap_CHI_Product_Test, bulkProdWrap_Negative_Test_1, bulkProdWrap_Negative_Test_2, bulkProdWrap_Negative_Test_3, bulkProdWrap_Negative_Test_4, bulkProdWrap_Negative_Test_5 = new NAC_BulkUploadController.bulkUploadProductWrapper();
        List<ContentVersion> contentVersionList = NAC_TestDataFactory.setUpContentDocument(4);
        contentVersionList[0].VersionData = Blob.valueOf('"Product Code","Quantity"\n'+
                                                         '"Test Product 1","23"\n'+
                                                         '"Test Product 2","34"\n'+
                                                         '"Test Product 3","31"\n'+
                                                         '"Test Product 4","31"\n'+
                                                         '"Test Product 5","17"\n'+
                                                         '"Test Product 1812","17"\n'+
                                                         '"Test Product 1812","17"\n'+
                                                         '"","1"\n'+
                                                         '"Test Product TEST","TEST"\n'+
                                                         '"Test Product 1718",""\n'+
                                                         '"Test Product 1209","-9"');
        contentVersionList[1].VersionData = Blob.valueOf('"Product Code","Quantity","SKU"\n'+
                                                         '"Test Product 1","23"');
        contentVersionList[2].VersionData = Blob.valueOf('"Product Code","Quantity"');
        contentVersionList[3].VersionData = Blob.valueOf(' ');
        insert contentVersionList;
        Set<Id> contentVersionIdList = new Set<Id>();
        for(ContentVersion cv : contentVersionList){
            contentVersionIdList.add(cv.Id);
        }
        Map<Id,ContentVersion> cvMap = new Map<Id,ContentVersion>([SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE Id IN :contentVersionIdList]);
        Account acc = NAC_TestDataFactory.insertAccount();
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc);
        
        String effectiveAccountId=acc.id;
        BuyerAccount buyerAccount=NAC_TestDataFactory.insertBuyerAccount(acc);
        Webstore web = NAC_TestDataFactory.webstoreCreation();
        WebCart cartCreate=NAC_TestDataFactory.cartCreation(web.id,data.acc.Id);
        List<CartItem> cartItem=[select Id,CartId,product2ID,product2.recordtypeid,Product2.NATT_CoreItem_P_N__c,Product2.NATT_P_N__c,Product2.recordType.Name,Product2.NATT_Core__c,Product2.NATT_Branch_Plant_Warehouse__c,product2.Name,CartDeliveryGroupId from cartItem where CartId=:cartCreate.id];
        Test.startTest();
        System.runAs(data.usr){
            bulkProdWrap_ATL_Product_Test = NAC_BulkUploadController.readUploadedFile(cvMap.get(contentVersionList[0].Id).ContentDocumentId,CommunityId,data.acc.Id,'ATL');
            bulkProdWrap_Negative_Test_1 = NAC_BulkUploadController.readUploadedFile(cvMap.get(contentVersionList[1].Id).ContentDocumentId,CommunityId,data.acc.Id,'ATL');
            bulkProdWrap_Negative_Test_2 = NAC_BulkUploadController.readUploadedFile(cvMap.get(contentVersionList[2].Id).ContentDocumentId,CommunityId,data.acc.Id,'ATL');
            bulkProdWrap_Negative_Test_3 = NAC_BulkUploadController.readUploadedFile(cvMap.get(contentVersionList[3].Id).ContentDocumentId,CommunityId,data.acc.Id,'ATL');
            bulkProdWrap_Negative_Test_4 = NAC_BulkUploadController.readUploadedFile(data.acc.Id,CommunityId,data.acc.Id,'ATL');
            bulkProdWrap_Negative_Test_5 = NAC_BulkUploadController.readUploadedFile(null,CommunityId,data.acc.Id,'ATL');
            bulkProdWrap_ANA_Product_Test = NAC_BulkUploadController.readUploadedFile(cvMap.get(contentVersionList[0].Id).ContentDocumentId,CommunityId,data.acc.Id,'ANA');
            bulkProdWrap_PAN_Product_Test = NAC_BulkUploadController.readUploadedFile(cvMap.get(contentVersionList[0].Id).ContentDocumentId,CommunityId,data.acc.Id,'PAN');
            bulkProdWrap_CHI_Product_Test = NAC_BulkUploadController.readUploadedFile(cvMap.get(contentVersionList[0].Id).ContentDocumentId,CommunityId,data.acc.Id,'CHI');
            
        }
        Test.stopTest();
        system.debug(bulkProdWrap_ATL_Product_Test);
         system.assert(!bulkProdWrap_ATL_Product_Test.hasError);
             system.assert(!bulkProdWrap_ATL_Product_Test.prodWrapList.isEmpty());
             for(NAC_BulkUploadController.ProductWrapper prodWrap : bulkProdWrap_ATL_Product_Test.prodWrapList){
                 switch on prodWrap.index {
                     when 1 {
                         system.assert(!prodWrap.hasError);
                         system.assert(prodWrap.errorMessageList.isEmpty());
                     }
                     when 2 {
                         system.assert(prodWrap.isSuperseded);
                     }
                     when 3 {
                         system.assert(prodWrap.hasError);
                         system.assert(prodWrap.errorMessageList.contains(System.Label.nac_Bulk_Upload_Error_Message_Product_Not_Orderable));
                     }
                     when 4 {
                         system.assert(prodWrap.hasError);
                         system.assert(prodWrap.errorMessageList.contains('Part is Superseded but not able to find any Active Superseded product'));
                     }
                     when 5 {
                         system.assert(prodWrap.hasError);
                         system.assert(prodWrap.errorMessageList.contains('Cannot order Core Product directly.'));
                     }
                     when 6 {
                         system.assert(prodWrap.hasError);
                         system.assert(prodWrap.errorMessageList.contains(System.Label.nac_Bulk_Upload_Error_Message_Wrong_Product_Number));
                     }when 7 {
                         system.assert(prodWrap.hasError);
                         system.assert(prodWrap.errorMessageList.contains(System.Label.nac_Bulk_Upload_Error_Message_Wrong_Product_Number));
                         system.assert(prodWrap.errorMessageList.contains(System.Label.nac_Bulk_Upload_Error_Message_Duplicate_Entry));
                     }
                     when 8 {
                         system.assert(prodWrap.hasError);
                         system.assert(prodWrap.errorMessageList.contains(System.Label.nac_Bulk_Upload_Error_Message_Product_Code_Blank));
                     }
                     when 9 {
                         system.assert(prodWrap.hasError);
                         system.assert(prodWrap.errorMessageList.contains(System.Label.nac_Bulk_Upload_Error_Message_Quantity_Not_Numeric));
                     }
                     when 10 {
                         system.assert(prodWrap.hasError);
                         system.assert(prodWrap.errorMessageList.contains(System.Label.nac_Bulk_Upload_Error_Message_Quantity_Blank));
                     }
                     when 11 {
                         system.assert(prodWrap.hasError);
                         system.assert(prodWrap.errorMessageList.contains(System.Label.nac_Bulk_Upload_Error_Message_Quantity_Less_than_0));
                     }
                 }
             }
             system.assert(bulkProdWrap_Negative_Test_1.hasError);
             system.assert(bulkProdWrap_Negative_Test_1.errorMessage.contains(System.Label.nac_Bulk_Upload_Error_Message_More_Than_2_column));
             system.assert(bulkProdWrap_Negative_Test_2.hasError);
             system.assert(bulkProdWrap_Negative_Test_2.errorMessage.contains(System.Label.nac_Bulk_Upload_Error_Message_Contains_Only_Header));
             system.assert(bulkProdWrap_Negative_Test_3.hasError);
             system.assert(bulkProdWrap_Negative_Test_3.errorMessage.contains(System.Label.nac_Bulk_Upload_Error_Message_CSV_Empty));
             system.assert(bulkProdWrap_Negative_Test_4.hasError);
             system.assert(bulkProdWrap_Negative_Test_4.errorMessage.contains(System.Label.nac_Bulk_Upload_Error_Message_Unable_Read_CSV));
             system.assert(bulkProdWrap_Negative_Test_5.hasError);
             system.assert(bulkProdWrap_Negative_Test_5.errorMessage.contains(System.Label.nac_Bulk_Upload_Error_Message_Query_Error));
    }

    @istest
    static void deleteContentDocumentFiles_Test(){
        List<ContentVersion> contentVersionList = NAC_TestDataFactory.setUpContentDocument(1);
        contentVersionList[0].VersionData = Blob.valueOf(' ');
        insert contentVersionList;
        ContentVersion cvList = [SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE Id = :contentVersionList[0].Id];
        NAC_BulkUploadController.deleteContentDocumentFiles(cvList.ContentDocumentId);
        List<ContentDocument> validateData = [SELECT Id from ContentDocument WHERE id = : cvList.ContentDocumentId];
        system.assert(validateData.isEmpty());
    }
    
    @IsTest(SeeAllData=true)
    static void addItemToCart_Test(){
        NAC_BulkUploadController.cartWrapper cartWrap = new NAC_BulkUploadController.cartWrapper();
        //NAC_BulkUploadController.cartWrapper cartWrap1 = new NAC_BulkUploadController.cartWrapper();
        returnData data = createData(true);

        List<ContentVersion> contentVersionList = NAC_TestDataFactory.setUpContentDocument(1);
        contentVersionList[0].VersionData = Blob.valueOf('"Product Code","Quantity"\n'+
                                                         '"Test Product 1","23"\n'+
                                                         '"Test Product 2","34"\n'+
                                                         '"Test Product 3","31"\n'+
                                                         '"Test Product 4","31"\n'+
                                                         '"Test Product 5","17"');
        insert contentVersionList;
        ContentVersion cvList = [SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE Id = :contentVersionList[0].Id];
        
          Account acc = NAC_TestDataFactory.insertAccount();
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc);
        
        String effectiveAccountId=acc.id;
        BuyerAccount buyerAccount=NAC_TestDataFactory.insertBuyerAccount(acc);
        
        BuyerGroup bg = NAC_TestDataFactory.insertBuyerGroup();
        BuyerGroupMember bgm = NAC_TestDataFactory.insertBuyerGroupMember(acc,bg);
        
        WebStore webstore = [SELECT id FROM WebStore WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC LIMIT 1];
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,webstore.id);
        WebStoreBuyerGroup wsbg = NAC_TestDataFactory.insertWebStoreBuyerGroup(webstore,bg);
        WebCart cartCreate=NAC_TestDataFactory.cartCreation(webstore.id,acc.id);
        System.assertNotEquals(cartCreate.Id,null,'Cart creation failed');
        Test.startTest();
        try{
            ConnectApi.CartSummary cartSummary=NAC_CartController.getCartSummary(communityId,effectiveAccountId,cartCreate.id);
        }catch(Exception e){
            
        }
        
        
        
        //Test.startTest();
        //System.runAs(data.usr){
            List<WebCart> webCartList = NAC_TestDataFactory.createWebCart(new Map<Id,Map<Id,String>>{NAC_B2BUtils.communityIdToWebStoreIdCache.get(communityId) => new Map<Id,String>{data.acc.Id => 'Active'}});
            insert webCartList;
            List<CartItem> validateDataBefore = [SELECT Id, Cart.OwnerId, Cart.Owner.Name FROM CartItem WHERE CartId =: webCartList[0].Id];
            System.assert(validateDataBefore.isEmpty());
            try{
                cartWrap = NAC_BulkUploadController.addItemToCart(JSON.Serialize(NAC_BulkUploadController.readUploadedFile(cvList.ContentDocumentId,CommunityId,data.acc.Id,'ATL')),CommunityId,data.acc.Id);

            }catch(Exception e){
                
            }
            
      // }
        Test.stopTest();
    }
    
    private class returnData{
        private User usr;
        private Account acc;
    } 
    
}