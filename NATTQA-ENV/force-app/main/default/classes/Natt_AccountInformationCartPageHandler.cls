public with sharing class Natt_AccountInformationCartPageHandler {
    @AuraEnabled
    public static List<WebCart> getCartList(String UserId, String CommunityId, String EffectiveAccountId) {
        String webStoreId = B2BUtils.resolveCommunityIdToWebstoreId(CommunityId);
        List <webCart> WebCartList = [SELECT Id, Name, WebStoreId, AccountId, IsSecondary,TotalProductAmount,TotalAmount, Status, NATT_Is_Cart_Primary__c, LastModifiedDate, TotalProductCount, UniqueProductCount
                                    FROM WebCart
                                    WHERE (Status = 'Active' OR Status = 'Checkout') AND (OwnerId = :UserId) AND WebStoreId = :webStoreId];
        List <WebCart> returnList = new List <WebCart>();
        for(WebCart cart : WebCartList){
            if(cart.AccountId == EffectiveAccountId){
                returnList.add(cart);
            }
        }
        return returnList;
    }

    @AuraEnabled
    public static Boolean checkForCheckoutCart(String UserId, String CommunityId) {
        String webStoreId = B2BUtils.resolveCommunityIdToWebstoreId(CommunityId);
        List<WebCart> WebCartList = [SELECT Id, Name, AccountId, IsSecondary,TotalProductAmount,TotalAmount, Status, NATT_Is_Cart_Primary__c, LastModifiedDate, TotalProductCount, UniqueProductCount
                                    FROM WebCart
                                    WHERE (Status = 'Checkout') AND (OwnerId = :UserId) AND (WebStoreId = :webStoreId)
        ];
        Boolean checkoutCheck = false;
        for (WebCart cart : WebCartList){
            if (cart.Status == 'Checkout'){
                checkoutCheck = true;
            } 
        }
        return checkoutCheck;
    }

    //Method used for "Make Primary" action on Carts screen
    @AuraEnabled
    public static List<WebCart>  makePrimary(Id WebCartId, String UserId, String CommunityId, String EffectiveAccountId){
        String webStoreId = B2BUtils.resolveCommunityIdToWebstoreId(CommunityId);
        User userRecord = [SELECT ContactId FROM User WHERE Id = :UserId];
        Contact userContact = [SELECT AccountId FROM Contact WHERE Id = :userRecord.ContactId];
        WebCart webCartValues = [SELECT Id, WebStoreId FROM WebCart WHERE Id = :WebCartId]; 
        List<WebCart> WebCartList = [SELECT Id, Name, AccountId, IsSecondary,TotalProductAmount,TotalAmount, Status, NATT_Is_Cart_Primary__c, LastModifiedDate, TotalProductCount, UniqueProductCount
                                        FROM WebCart
                                        WHERE (Status = 'Checkout') AND (OwnerId = :UserId) AND (WebStoreId = :webStoreId)
        ];
        List<WebCart>checkoutToActiveList = new List<WebCart>();
        for (WebCart cart : WebCartList){
            if (cart.Status == 'Checkout'){
                cart.Status = 'Active';
                checkoutToActiveList.add(cart);
            } 
        }
        update checkoutToActiveList;
        ConnectApi.CommerceActionResult primaryCart = ConnectApi.CommerceCart.makeCartPrimary(webCartValues.WebStoreId, WebCartId, EffectiveAccountId);
        return [SELECT Id, Name, AccountId, IsSecondary, WebStoreId, Status, TotalProductAmount, TotalAmount, NATT_Is_Cart_Primary__c, LastModifiedDate, TotalProductCount
            FROM WebCart
            WHERE (OwnerId = :UserId) AND (Status = 'Active' OR Status = 'Checkout') AND (WebStoreId = :webCartValues.WebStoreId)
        ];

    }


    //Method used for New Cart creation on Carts screen. Called from [Create New Cart] button
    @AuraEnabled
    public static List<WebCart> newCartApi(Id UserId, String CartName, String CommunityId, String EffectiveAccountId){
        String webStoreId = B2BUtils.resolveCommunityIdToWebstoreId(CommunityId);
        List<WebCart> WebCartList = [SELECT Id, Name, AccountId, IsSecondary,TotalProductAmount,TotalAmount, Status, NATT_Is_Cart_Primary__c, LastModifiedDate, TotalProductCount, UniqueProductCount
                                        FROM WebCart
                                        WHERE (Status = 'Checkout' OR Status = 'Active') AND (OwnerId = :UserId) AND (WebStoreId = :webStoreId)
        ];
        List <WebCart> EffectiveAccountCarts = new List <WebCart>();
        for(WebCart cart : WebCartList){
            if(cart.AccountId == EffectiveAccountId){
               
                EffectiveAccountCarts.add(cart);
            }
        }
        List<WebCart>checkoutToActiveList = new List<WebCart>();

        for (WebCart cart : EffectiveAccountCarts){
            if (cart.Status == 'Checkout'){
            // makeCartPrimary
                cart.Status = 'Active';
                checkoutToActiveList.add(cart);
                // checkoutToActiveList.add(cart);
            } 
            if(cart.NATT_Is_Cart_Primary__c == true){
                cart.Name = CartName;
                cart.isSecondary = true;
                checkoutToActiveList.add(cart);
            }
        }
        // update WebCartList;
        update checkoutToActiveList;

        ConnectApi.CartInput newCart = new ConnectApi.CartInput();
        newCart.isSecondary = false;
        Date todayDate = date.today();
        newCart.name = 'New Cart ' + todayDate.format();
        newCart.effectiveAccountId = EffectiveAccountId;

        ConnectApi.CartSummary newCartSummary = ConnectApi.CommerceCart.createCart(
            webStoreId, 
            newCart);
         List<WebCart> FinalWebCart = [SELECT Id, Name, AccountId, IsSecondary,TotalProductAmount,TotalAmount, Status, NATT_Is_Cart_Primary__c, LastModifiedDate, TotalProductCount, UniqueProductCount
                                        FROM WebCart
                                        WHERE (Status = 'Checkout' OR Status = 'Active') AND (OwnerId = :UserId) AND (WebStoreId = :webStoreId)
        ];
        
        List <WebCart> NewEffectiveCarts = new List <WebCart>();
        for(WebCart cart : WebCartList){
            if(cart.AccountId == EffectiveAccountId){
                System.debug('Account Id Match');
                NewEffectiveCarts.add(cart);
            }
        }
        return NewEffectiveCarts;
    }

    //Method used for "Delete Cart" action on Carts screen
    @AuraEnabled
    public static List<WebCart> deleteCarts(Id WebCartId, Id UserId, String EffectiveAccountId){     
        User userRecord = [SELECT ContactId FROM User WHERE Id = :UserId];
        Contact userContact = [SELECT AccountId FROM Contact WHERE Id = :userRecord.ContactId];
        String acctValue = null;
        String webStoreValue = null;
        WebCart webCartValues = [SELECT Id, WebStoreId, OwnerId FROM WebCart WHERE Id = :WebCartId];

        ConnectApi.CommerceCart.deleteCart(webCartValues.WebStoreId, EffectiveAccountId, WebCartId);
        List<WebCart> updatedWebCart = [SELECT Id, Name, AccountId, IsSecondary, WebStoreId, Status, TotalProductAmount, TotalAmount, NATT_Is_Cart_Primary__c, LastModifiedDate, TotalProductCount
                                        FROM WebCart
                                        WHERE (OwnerId = :webCartValues.OwnerId) AND (Status = 'Active' OR Status = 'Checkout') 
        ];
        List <WebCart> updatedEffectiveCarts = new List <WebCart>();
        for(WebCart cart : updatedWebCart){
            if(cart.AccountId == EffectiveAccountId){
                updatedEffectiveCarts.add(cart);
            }
        }
        return updatedEffectiveCarts;
    }

    //Method used for "Rename Cart" action on Carts screen
    @AuraEnabled
    public static List<WebCart> renameCarts(Id WebCartId, Id UserId, String newName, String EffectiveAccountId){
        WebCart webCartValues = [SELECT Id, WebStoreId, Name, OwnerId FROM WebCart WHERE Id = :WebCartId];
        webCartValues.Name = newName;
        update webCartValues;
        List<WebCart> updatedWebCarts = [SELECT Id, Name, AccountId, IsSecondary, WebStoreId, Status, TotalProductAmount, TotalAmount, NATT_Is_Cart_Primary__c, LastModifiedDate, TotalProductCount, OwnerId
                                        FROM WebCart
                                        WHERE (OwnerId = :webCartValues.OwnerId) AND (Status = 'Active' OR Status = 'Checkout') AND (WebStoreId = :webCartValues.WebStoreId)
        ];
        List <WebCart> updatedEffectiveCarts = new List <WebCart>();
        for(WebCart cart : updatedWebCarts){
            if(cart.AccountId == EffectiveAccountId){
                updatedEffectiveCarts.add(cart);
            }
        }
        return updatedEffectiveCarts;
    }

}