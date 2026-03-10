global class NATT_TesCalculateTax {
    @InvocableMethod(label='Calculate Cart Tax' description='Runs a synchronous version of cart taxes' category='B2B Commerce')
    global static void calculateCartTax(List<TaxInputActionRequest> input) {
        TaxInputActionRequest taxRequest = input.get(0);
        CartTax[] cartTaxestoInsert = new CartTax[]{};
        for (CartItem cartItem : [SELECT Sku,Product2.NATT_P_N__c, TotalPrice, Type, Cart.NATT_TaxPercent__c FROM CartItem WHERE CartId = :taxRequest.cartId]) {
            CartTax tax = new CartTax( 
                Amount = ((cartItem.TotalPrice==null?0:cartItem.TotalPrice)*(cartItem.Cart.NATT_TaxPercent__c==null?0:cartItem.Cart.NATT_TaxPercent__c)),                    
                CartItemId = cartItem.Id,
                Name = String.isBlank(cartItem.Product2.NATT_P_N__c)?'unknown':cartItem.Product2.NATT_P_N__c,
                TaxCalculationDate = Date.today(),
                TaxRate = cartItem.Cart.NATT_TaxPercent__c==null?0.0:cartItem.Cart.NATT_TaxPercent__c,
                TaxType = 'Estimated'
            );
            cartTaxestoInsert.add(tax);
        }
        
        delete [SELECT Id FROM CartTax WHERE CartId=:taxRequest.cartId];
        
        insert(cartTaxestoInsert);
    }

    global class TaxInputActionRequest{
        @InvocableVariable(required=true)
        global String cartId;
    }
}