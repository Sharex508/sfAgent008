({
	doInit : function(cmp, event, helper) {
        if(cmp.get("v.recordId").startsWith('801')){
            helper.getOrderData(cmp);
        }else{
			helper.getQuoteData(cmp);
        }
	},
    handleAddressChange : function(cmp,event,helper){
        if(cmp.get("v.recordId").startsWith('801')){
            helper.updateAddressOnOrder(cmp);
        }else{
        	helper.updateAddress(cmp);
        }
    }
})