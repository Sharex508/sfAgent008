({
	getQuoteData : function(cmp){
    	let action = cmp.get("c.getQuoteInfo");
        action.setParams({"qId" : cmp.get("v.recordId")});
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                let quote = response.getReturnValue();                
                cmp.set("v.selectedShippingAddressId",quote.SBQQ__Opportunity2__r.NATT_Shipping_Address__c);
                cmp.set("v.selectedBillingAddressId",quote.SBQQ__Opportunity2__r.NATT_Billing_Address__c);
                cmp.set("v.endCustomerId",quote.SBQQ__Opportunity2__r.NATT_End_Customer__c);
                cmp.set("v.oppId",quote.SBQQ__Opportunity2__c);
                cmp.set("v.dealerId",quote.SBQQ__Account__c);
            }
            else if (state === "INCOMPLETE") {
                console.log('incomplete');
            }
            else if (state === "ERROR") {
                var errors = response.getError();
                if (errors) {
                    if (errors[0] && errors[0].message) {
                        console.log("Error message: " + errors[0].message);
                    }
                } else {
                    console.log("Unknown error");
                }
            }
        });
        $A.enqueueAction(action);
	},
    getOrderData : function(cmp){
    	let action = cmp.get("c.getOrderInfo");
        action.setParams({"oId" : cmp.get("v.recordId")});
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                let ord = response.getReturnValue();                
                cmp.set("v.selectedShippingAddressId",ord.NATT_Shipping_Address__c);
                cmp.set("v.selectedBillingAddressId",ord.NATT_Billing_Address__c);
                cmp.set("v.endCustomerId",ord.NATT_End_Customer__c);
                cmp.set("v.dealerId",ord.AccountId);
            }
            else if (state === "INCOMPLETE") {
                console.log('incomplete');
            }
            else if (state === "ERROR") {
                var errors = response.getError();
                if (errors) {
                    if (errors[0] && errors[0].message) {
                        console.log("Error message: " + errors[0].message);
                    }
                } else {
                    console.log("Unknown error");
                }
            }
        });
        $A.enqueueAction(action);
	},
    updateAddress : function(cmp){
        this.showSpinner(cmp);
        let action = cmp.get("c.updateQuote");
        action.setParams({
            "quoteId" : cmp.get("v.recordId"),
            "oppId" : cmp.get("v.oppId"),
            "billingAddressId" : cmp.get("v.selectedBillingAddressId"),
            "shippingAddressId" : cmp.get("v.selectedShippingAddressId")
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                let toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Success",
                    "message": "Address information updated.",
                    "type" : "success"
                });            
                toastEvent.fire();
                $A.get('e.force:refreshView').fire();
            }
            else if (state === "INCOMPLETE") {
                console.log('incomplete');
            }
            else if (state === "ERROR") {
                var errors = response.getError();
                if (errors) {
                    if (errors[0] && errors[0].message) {
                        console.log("Error message: " + errors[0].message);
                    }
                } else {
                    console.log("Unknown error");
                }
            }
            this.hideSpinner(cmp);
        });
        $A.enqueueAction(action);
    },
    updateAddressOnOrder : function(cmp){
        this.showSpinner(cmp);
        let action = cmp.get("c.updateOrder");
        action.setParams({
            "orderId" : cmp.get("v.recordId"),            
            "billingAddressId" : cmp.get("v.selectedBillingAddressId"),
            "shippingAddressId" : cmp.get("v.selectedShippingAddressId")
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                let toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Success",
                    "message": "Address information updated.",
                    "type" : "success"
                });            
                toastEvent.fire();
                $A.get('e.force:refreshView').fire();
            }
            else if (state === "INCOMPLETE") {
                console.log('incomplete');
            }
            else if (state === "ERROR") {
                var errors = response.getError();
                if (errors) {
                    if (errors[0] && errors[0].message) {
                        console.log("Error message: " + errors[0].message);
                    }
                } else {
                    console.log("Unknown error");
                }
            }
            this.hideSpinner(cmp);
        });
        $A.enqueueAction(action);
    },
    showSpinner : function(cmp){
        cmp.set("v.isProcessing",true);
    },
    hideSpinner : function(cmp){
        cmp.set("v.isProcessing",false);
    },
})