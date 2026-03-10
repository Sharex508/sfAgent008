({
	doInit : function(cmp) {
        if(cmp.get("v.dealerId")||cmp.get("v.endCustomerId")){
			this.getAddressData(cmp);		
        }
	},
    getAddressData : function(cmp){
    	let action = cmp.get("c.getAddressList");
        action.setParams({
            			  "dealerId" : cmp.get("v.dealerId"),
            			  "endCustomerId" : cmp.get("v.endCustomerId"),
            			  "addressType" : cmp.get("v.addressType")
                         });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                cmp.set("v.wrap",response.getReturnValue());    
                console.log(JSON.stringify(cmp.get("v.wrap")));
                if(cmp.get("v.addressType")=="Billing" && cmp.get("v.wrap").defaultBillingAddressId){
                    cmp.set("v.selectedAddressId",cmp.get("v.wrap").defaultBillingAddressId);
                }
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
})