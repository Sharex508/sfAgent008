/**
* @description Demonstrates how to make Apex calls to ConnectApi.CommerceCart class
* to perform Cart Operations for B2B Commerce on Lightning.
*
* @see B2BUtils
*/
public with sharing class NAC_CartController { 
    /**
* @description Demonstrates how to call ConnectApi.CommerceCart.getCartItems
* @param  communityId The Id of the community from which the call originated
* @param effectiveAccountId ID of the account for which the request is made. If null, defaults to the account ID for the context user.
* @param activeCartOrId ID of the cart, active, or current.
* @param pageParam Specifies the page token to be used to view a page of information.
* @param sortParam Sort order for items in a cart.
* @return CartItemCollection A collection of cart items
*/
    @AuraEnabled
    public static ConnectApi.CartItemCollection getCartItems(
        String communityId,
        String effectiveAccountId,
        String activeCartOrId,
        Integer pageSize,
        String pageParam,
        String sortParam
    ) {
        // Lookup the webstore ID associated with the community
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        
        // Get the ConnectApi.CartItemSortOrder enum value from string.
        // For the list of possible values, see:
        // see https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/connectAPI_enums.htm#cartItemSortOrderEnum
        ConnectApi.CartItemSortOrder resolvedSortParam = NAC_B2BUtils.resolveSortParam(
            sortParam
        );
        
        // For more details, see:
        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_ConnectAPI_CommerceCart_static_methods.htm
        return ConnectApi.CommerceCart.getCartItems(
            webstoreId,
            effectiveAccountId,
            activeCartOrId,
            'NATT_DirectDelivery__c,NATT_ItemPriceGroup__c,ProductCode,NATT_Core__c,NATT_CoreItem_P_N__c',
            pageParam,
            pageSize,
            resolvedSortParam 
        );
    }

    
    @AuraEnabled
    public static cartValidateResultWrapper cartValidate(String communityId, String effectiveAccountId, String activeCartOrId, String pageParam, String sortParam, String selectedWarehouse){
        cartValidateResultWrapper cartValidateWrap = new cartValidateResultWrapper();
        //String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        Set<Id> invalidProductIdSet = new Set<Id>();
        Map<Id,Id> cartItemToProductMap = new Map<Id,Id>();
        Map<String,Set<Id>> coreToProductMap = new Map<String,Set<Id>>();
        Map<String,String> coreIdToProductCodeMap = new Map<String,String>();
        Map<String,String> mainProdCodeWithIdMap = new Map<String,String>();
        //Query all the products that are tagged to the current cart      
        List<cartItem> cartItemList = [SELECT Id, SalesPrice, Product2Id, Product2.NATT_Core__c, Product2.NAOCAP_Not_Orderable_ANA__c, Product2.NAOCAP_Not_Orderable__c, Product2.NAOCAP_Not_Orderable_CHI__c, Product2.NAOCAP_Not_Orderable_PAN__c, Product2.ProductCode, Product2.NATT_CoreItem_P_N__c FROM CartItem where CartId =: activeCartOrId];
        cartValidateWrap.cartItemCount = cartItemList.size();
        for(cartItem item : cartItemList){
            if(!item.Product2.NATT_Core__c){
                mainProdCodeWithIdMap.put(item.Product2.ProductCode,item.Product2Id);
                if(String.isNotBlank(item.Product2.NATT_CoreItem_P_N__c)){
                    if(!coreToProductMap.containsKey(item.Product2.NATT_CoreItem_P_N__c)){
                        coreToProductMap.put(item.Product2.NATT_CoreItem_P_N__c, new Set<Id>());
                    }
                    coreToProductMap.get(item.Product2.NATT_CoreItem_P_N__c).add(item.Product2Id);
                }
                if((selectedWarehouse.equalsIgnoreCase('ATL') && item.Product2.NAOCAP_Not_Orderable__c) || (selectedWarehouse.equalsIgnoreCase('ANA') && item.Product2.NAOCAP_Not_Orderable_ANA__c) || (selectedWarehouse.equalsIgnoreCase('CHI') && item.Product2.NAOCAP_Not_Orderable_CHI__c) || (selectedWarehouse.equalsIgnoreCase('PAN') && item.Product2.NAOCAP_Not_Orderable_PAN__c) || (item.SalesPrice != null && item.SalesPrice == 0)){
                    invalidProductIdSet.add(item.Product2Id);
                }
            }else{
                coreIdToProductCodeMap.put(item.Product2Id, item.Product2.ProductCode);
            }
        }
        // For Panama Selected warehouse if any Product in cart Direct delivery is checked true then its not Orderable 
        if(selectedWarehouse.equalsIgnoreCase('PAN')&& !mainProdCodeWithIdMap.isEmpty()){            
            List<Product2> productWithPANDDList = [SELECT ProductCode FROM Product2 where Recordtype.Name='NAC Products' and ProductCode IN :mainProdCodeWithIdMap.keyset() and NATT_Branch_Plant_Warehouse__c = 'PAN' AND NATT_DirectDelivery__c = true AND NATT_Core__c = false];
            for(Product2 prod:productWithPANDDList){
                if(mainProdCodeWithIdMap.containskey(prod.ProductCode)){
                    //Add the atlanta ID because our Cart works with Atlanta ID in order to successfuly delete
                    invalidProductIdSet.add(mainProdCodeWithIdMap.get(prod.ProductCode));
                }                    
            }            
        }
        for(cartItem item : cartItemList){
            if(item.Product2.NATT_Core__c && coreIdToProductCodeMap.containsKey(item.Product2Id)){
                //If there is a core product in cart without its associated product, then delete it
                if(!coreToProductMap.containsKey(coreIdToProductCodeMap.get(item.Product2Id))){
                    invalidProductIdSet.add(item.Product2Id);
                }else{
                    //If the non core part is invalid then delete its core as well
                    boolean removeCoreProduct = true;
                    for(Id prodId : coreToProductMap.get(coreIdToProductCodeMap.get(item.Product2Id))){
                        if(!invalidProductIdSet.contains(prodId)){
                            removeCoreProduct = false;
                        }
                    }
                    if(removeCoreProduct){
                        invalidProductIdSet.add(item.Product2Id);
                    }
                }
            }
            //If the main product is present without its core, remove it
            else if(!item.Product2.NATT_Core__c && String.isNotBlank(item.Product2.NATT_CoreItem_P_N__c) && !coreIdToProductCodeMap.values().contains(item.Product2.NATT_CoreItem_P_N__c)){
                invalidProductIdSet.add(item.Product2Id);
            }
        }
        for(cartItem item : cartItemList){
            if(invalidProductIdSet.contains(item.Product2Id)){
                cartValidateWrap.invalidCartItems.put(item.Id, item.Product2.ProductCode);
            }
        }
        return cartValidateWrap;
    }

    @AuraEnabled
    public static Boolean cartValidateDelete(String communityId,String effectiveAccountId, String activeCartOrId,Map<String,String> cartItemToDelete){
        Boolean isDelete =false;
        //Just delete the records simply
        Database.DeleteResult[] deleteResultList = Database.Delete([SELECT Id FROM CartItem Where Id IN:cartItemToDelete.keyset()],false);
        // Iterate through each returned result
        for(Database.DeleteResult dr : deleteResultList) {
            if (dr.isSuccess()) {
                isDelete = true;
            }
            else {
                isDelete = false;
                // Operation failed, so get all errors                
                for(Database.Error err : dr.getErrors()) {          
                    System.debug(err.getStatusCode() + ': ' + err.getMessage());
                }
                break;
            }
        }
        return isDelete;
    }
    
    /**
* @description Demonstrates how to call ConnectApi.CommerceCart.updateCartItem
* @param  communityId The Id of the community from which the call originated
* @param effectiveAccountId ID of the account for which the request is made. If null, defaults to the account ID for the context user.
* @param activeCartOrId ID of the cart, active, or current.
* @param cartItemId ID of the cart item to be updated.
* @return CartItem The updated cart item
*/
    @AuraEnabled
    public static List<ConnectApi.CartItem> updateCartItem(
        String communityId,
        String effectiveAccountId,
        String activeCartOrId,
        String cartItemId,
        ConnectApi.CartItemInput cartItem 
    ) {
        // Lookup the webstore ID associated with the community
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        String qty=cartItem.Quantity;
        String pCartItemID=cartItemId;
        List<ConnectApi.CartItem> listofReturnedcartItem=new List<ConnectApi.CartItem>();
        CartITem cartCoreOriginalPr=[select id,Product2Id,CartId,Quantity from CartITem where id=:cartItemId LIMIT 1];        
        Decimal Delta=Decimal.valueOf(cartItem.Quantity)- cartCoreOriginalPr.Quantity;
        try{
            String corePrId=NAC_B2BUtils.returnCoreItemID(cartItemId);            
            if(corePrId != null){
                CartITem crtCore=[select id,Product2Id,CartId ,Quantity from CartITem where Product2Id=:corePrId AND CartId=:cartCoreOriginalPr.CartId LIMIT 1];                cartItem.Quantity =String.ValueOf(crtCore.Quantity+Delta);
                cartItemId = crtCore.id;
                try{
                    ConnectApi.CartItem coreCartItem=ConnectApi.CommerceCart.updateCartItem(webstoreId,effectiveAccountId,activeCartOrId,cartItemId,cartItem);
                    listofReturnedcartItem.add(coreCartItem);
                }
                catch(exception e){
                    system.debug('Exception@@2'+e);
                } 
            }
        }
        catch(exception e){
            system.debug('Exception'+e);
        }
        
        cartItemId=pCartItemID;
        cartItem.Quantity=qty;
        ConnectApi.CartItem originalcartItem=ConnectApi.CommerceCart.updateCartItem(
            webstoreId,
            effectiveAccountId,
            activeCartOrId,
            cartItemId,
            cartItem
        );
        listofReturnedcartItem.add(originalcartItem);
        //}
        
        // For more details, see:
        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_ConnectAPI_CommerceCart_static_methods.htm
        return listofReturnedcartItem;
    }
    
    /**
* @description Demonstrates how to call ConnectApi.CommerceCart.deleteCartItem
* @param  communityId The Id of the community from which the call originated
* @param effectiveAccountId ID of the account for which the request is made. If null, defaults to the account ID for the context user.
* @param activeCartOrId ID of the cart, active, or current.
* @param cartItemId ID of the cart item to be deleted.
*/
    @AuraEnabled
    public static List<String> deleteCartItem(
        String communityId,
        String effectiveAccountId,
        String activeCartOrId,
        String cartItemId,
        ConnectApi.CartItemInput cartItem 
    ) {
        // Lookup the webstore ID associated with the community
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        String pCartItemID = cartItemId;
        String qty = cartItem.Quantity;
        List<String> listtoDeletecartItem = new List<String>();
        CartItem cartItm = [select id, Product2Id, CartId, Quantity from CartItem where id =: cartItemId LIMIT 1];
        String corePrId=NAC_B2BUtils.returnCoreItemID(cartItemId);
        if(corePrId != null){
            List<CartItem> crtCore = [SELECT Id, Product2Id, CartId, Quantity from CartItem where Product2Id =: corePrId AND CartId =: cartItm.CartId LIMIT 1];
            if(!crtCore.isEmpty()){
                Decimal coreQuantityIntheCart = crtCore[0].Quantity;
                cartItemId = crtCore[0].id;
                try{
                    if(coreQuantityIntheCart == Decimal.valueOf(qty)){
                        listtoDeletecartItem.add(cartItemId);
                        ConnectApi.CommerceCart.deleteCartItem(webstoreId,effectiveAccountId,activeCartOrId,cartItemId);
                    }else{
                        Decimal delta = coreQuantityIntheCart - Decimal.valueOf(qty);
                        cartItem.quantity = String.ValueOf(delta);   
                        ConnectApi.CartItem coreCartItem=ConnectApi.CommerceCart.updateCartItem(webstoreId,effectiveAccountId,activeCartOrId,cartItemId,cartItem);
                    }
                }
                catch(exception e){
                    system.debug('e@@@'+e);
                }  
            }
        }
        cartItemId=pCartItemID;
        listtoDeletecartItem.add(cartItemId);
        // For more details, see:
        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_ConnectAPI_CommerceCart_static_methods.htm
        ConnectApi.CommerceCart.deleteCartItem(
            webstoreId,
            effectiveAccountId,
            activeCartOrId,
            cartItemId
        );
        return listtoDeletecartItem;
    }
    
    /**
* @description Demonstrates how to call ConnectApi.CommerceCart.getCartSummary
* @param  communityId The Id of the community from which the call originated
* @param effectiveAccountId ID of the account for which the request is made. If null, defaults to the account ID for the context user.
* @param activeCartOrId ID of the cart, active, or current.
*/
    @AuraEnabled
    public static ConnectApi.CartSummary getCartSummary(
        String communityId,
        String effectiveAccountId,
        String activeCartOrId
    ) {
        // Lookup the webstore ID associated with the community
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        
        // For more details, see:
        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_ConnectAPI_CommerceCart_static_methods.htm
        return ConnectApi.CommerceCart.getCartSummary(
            webstoreId,
            effectiveAccountId,
            activeCartOrId
        );
    }
    
    /**
* @description Demonstrates how to call ConnectApi.CommerceCart.createCart
* @param  communityId The Id of the community from which the call originated
* @param effectiveAccountId ID of the account for which the request is made. If null, defaults to the account ID for the context user.
*/
    @AuraEnabled
    public static ConnectApi.CartSummary createCart(
        String communityId,
        String effectiveAccountId
    ) {
        // Lookup the webstore ID associated with the community
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        ConnectApi.CartInput cartInput = new ConnectApi.CartInput();
        cartInput.effectiveAccountId = effectiveAccountId;
        // For more details, see:
        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_ConnectAPI_CommerceCart_static_methods.htm
        return ConnectApi.CommerceCart.createCart(webstoreId, cartInput);
    }
    
    /**
* @description Demonstrates how to call ConnectApi.CommerceCart.deleteCart
* @param  communityId The Id of the community from which the call originated
* @param effectiveAccountId ID of the account for which the request is made. If null, defaults to the account ID for the context user.
* @param activeCartOrId ID of the cart, active, or current.
*/
    @AuraEnabled
    public static void deleteCart(
        String communityId,
        String effectiveAccountId,
        String activeCartOrId
    ) {
        // Lookup the webstore ID associated with the community
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        
        // For more details, see:
        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_ConnectAPI_CommerceCart_static_methods.htm
        ConnectApi.CommerceCart.deleteCart(
            webstoreId,
            effectiveAccountId,
            activeCartOrId
        );
    }
    
    public class cartValidateResultWrapper{
        @AuraEnabled public Map<String,String> invalidCartItems;
        @AuraEnabled public integer cartItemCount;
        cartValidateResultWrapper(){
            invalidCartItems = new Map<String,String>();
            cartItemCount = 0;
        }
    }
}