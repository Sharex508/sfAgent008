({
    isCommunity : function(component,event) {
        var action = component.get("c.isCommunity_Apex");
        action.setCallback(this, function(response){
            var state = response.getState();
            if(state === "SUCCESS"){
                var isCommunity = response.getReturnValue();
                component.set("v.isCommunity",isCommunity);               
            }
        });
        $A.enqueueAction(action);
    },
    
    isJDESalesOrder_Null: function(component,event) {
        var action = component.get("c.isJDESalesOrder_NotNull");
        action.setParams({"selectedOrderId" : component.get("v.recordId")});
        action.setCallback(this, function(response){
            var state = response.getState();
            if(state === "SUCCESS"){
                var jdeSalesOrder = response.getReturnValue();
                if(jdeSalesOrder == false){
                    var toastEvent = $A.get("e.force:showToast");
                    toastEvent.setParams({
                        "title": "Error!",
                        "message": "You may not update this order because it does not have JDE Sales Order # yet.",
                        "type" : "warning"
                    });
                    toastEvent.fire();
                    $A.get("e.force:closeQuickAction").fire();
                }
            }
        });
        $A.enqueueAction(action);
    },
    
    getOpenAmendmentOrderNumber : function(component,event) {
        var action = component.get("c.getOpenAmendmentOrderNumber_Apex");
        action.setParams({"selectedOrderId" : component.get("v.recordId")});
        action.setCallback(this, function(response){
            var state = response.getState();
            if(state === "SUCCESS"){
                var openAmendmentOrderNumber = response.getReturnValue();
                component.set("v.openAmendmentOrderNumber",openAmendmentOrderNumber);
            }
        });
        $A.enqueueAction(action);
    },
    
    hasOpenAmendment2 : function(component,event) {
        var action = component.get("c.hasOpenAmendment2_Apex");
        action.setParams({"selectedOrderId" : component.get("v.recordId")});
        action.setCallback(this, function(response){
            var state = response.getState();
            if(state === "SUCCESS"){
                var hasOpenAmendment = response.getReturnValue();
                if(hasOpenAmendment == true){
                    var openAmendmentOrderNumber = component.get("v.openAmendmentOrderNumber");
                    var toastEvent = $A.get("e.force:showToast");
                    toastEvent.setParams({
                        "title": "Error!",
                        "type" : "warning",
                        "message": "message",
                                "messageTemplate": 'There is already an amendment order. Order# {0}',
                                "messageTemplateData": [openAmendmentOrderNumber]
                    });
                    toastEvent.fire();
                    $A.get("e.force:closeQuickAction").fire();
                }
            }
        });
        $A.enqueueAction(action);
    },
    
    hasOpenAmendment : function(component,event) {
        var action = component.get("c.hasOpenAmendment_Apex");
        action.setParams({"selectedOrderId" : component.get("v.recordId")});
        action.setCallback(this, function(response){
            var state = response.getState();
            if(state === "SUCCESS"){
                var hasOpenAmendment = response.getReturnValue();
                if(hasOpenAmendment == true){
                    var toastEvent = $A.get("e.force:showToast");
                    toastEvent.setParams({
                        "title": "Error!",
                        "type" : "warning",
                        "message": "There is currently a change in-progress. Finish that opportunity or mark it as Closed Lost before starting a new change."
                    });
                    toastEvent.fire();
                    $A.get("e.force:closeQuickAction").fire();
                }
            }
        });
        $A.enqueueAction(action);
    },
    
    validateRequestedDatePriceChanges : function(component,event,orderLineItemId,newReqShipDate) {
        var orderlines = component.get("v.units");        
        var requestedShipDate = newReqShipDate;//event.getParam("value").toString();
        var orderItemId = orderLineItemId;//event.getSource().get('v.name');
        
        let isValidChange=false;
        var action = component.get("c.validateRequestedDatePriceChanges_Apex");
        var p = new Promise($A.getCallback( function( resolve , reject ) {
            action.setParams({"newRequestedShipDate" : requestedShipDate,
                              "orderItemId" : orderItemId});
            action.setCallback(this, function(response) {
                var state = response.getState();
                if (state === "SUCCESS") {
                    isValidChange = response.getReturnValue();                 
                    console.log('isValidChange:'+isValidChange);
                    resolve(isValidChange);
                }else if (state === "INCOMPLETE") {
                    console.log('incomplete');
                    reject(isValidChange);
                }else if (state === "ERROR") {
                    console.log('orderItemId with error:'+orderItemId);
                    //let rec =orderlines.find(row => row.orderItemId === orderItemId);                
                    var errors = action.getError();
                    if (errors) {
                        if (errors[0] && errors[0].message) {
                            this.hideSpinner(component);
                            component.set("v.errorMessage",errors[0]);
                            component.set("v.isError",true);
                            var toastEvent = $A.get("e.force:showToast");
                            toastEvent.setParams({
                                title: 'Error',
                                type: 'error',
                                message: errors[0].message
                            });
                            toastEvent.fire(); 
                        }
                    }
                    rejectIsValidChange(isValidChange);
                }
                
                if(!isValidChange){
                    component.find('notifLib').showToast({
                        "title": "Error",
                        "variant":"error",
                        "message": "Requested ship date can not be changed because it involves price changes. Pricing for units on an order must be consistent. Please initiate a new quote for these new Requested ship dates."
                    });                 
                }
                console.log('about to return isValidChange:'+isValidChange);                
            });
            $A.enqueueAction(action);
        }));
        return p;
    },
    
    
    saveRequestedShipDateChanges : function(component,event,orderLineItem,newReqShipDate) {
        var orgTimeZone = $A.get("$Locale.timezone"); //Time Zone Preference in Salesforce
        var orgDateToday = new Date().toLocaleDateString("en-US", {timeZone: orgTimeZone}); //Date Instance with Salesforce Locale timezone
        var convertedNewReqShipDate = new Date(newReqShipDate).toLocaleDateString();
        var convertedNewReqShipDate2 = Math.round(new Date(convertedNewReqShipDate).getTime()/1000);
        var orgDateToday2 = Math.round(new Date(orgDateToday).getTime()/1000);
        
        if(convertedNewReqShipDate2 < orgDateToday2){
            var toastEvent = $A.get("e.force:showToast");
            toastEvent.setParams({
                title: 'Error',
                type: 'error',
                message: "Past dates are not allowed."
            });
            toastEvent.fire();
        }
        else{
            this.validateRequestedDatePriceChanges(component,event,orderLineItem,newReqShipDate)
            .then(function(result){
                console.log('returned:'+result);
                if(result){
                    console.log('is valid change'+newReqShipDate);
                    var action = component.get("c.saveRequestedShipDateChanges_Apex");
                    action.setParams({"selectedOrderId" : component.get("v.recordId"),
                                      "newReqShipDate" : newReqShipDate,
                                      "orderItemId" : orderLineItem});
                    action.setCallback(this, function(response) {
                        console.log('inside callback');
                        var state = response.getState();
                        console.log('state'+state);
                        if (state === "SUCCESS") {
                            var response = response.getReturnValue(); 
                            // this.hideSpinner(component);
                            component.find('notifLib').showToast({
                                "title": "Success",            
                                "message": "Requested ship date was successfully changed."
                            });                
                        }else if (state === "INCOMPLETE") {
                            console.log('incomplete');
                        }else if (state === "ERROR") {
                            var errors = action.getError();
                            console.log(errors);
                            if (errors) {
                                if (errors[0] && errors[0].message) {
                                    this.hideSpinner(component);
                                    component.set("v.errorMessage",errors[0]);
                                    component.set("v.isError",true);
                                    var toastEvent = $A.get("e.force:showToast");
                                    toastEvent.setParams({
                                        title: 'Error',
                                        type: 'error',
                                        message: errors[0].message
                                    });
                                    toastEvent.fire();
                                }
                            }
                        }
                    });
                    $A.enqueueAction(action);
                }}); 
        }
    },
    
    getShipmentMethodEditable : function(component,event){
        var action = component.get("c.getShipmentMethodEditable_Apex");
        action.setParams({"selectedOrderId" : component.get("v.recordId")});
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var response = response.getReturnValue();
                component.set("v.orderHeaderEditable",response);                
            }else if (state === "INCOMPLETE") {
                console.log('incomplete');
            }else if (state === "ERROR") {
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
    
    fetchRelatedUnits : function(component,event){
        var action = component.get("c.fetchRelatedUnits_Apex");
        action.setParams({"selectedOrderId" : component.get("v.recordId")});
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var response = response.getReturnValue();
                console.log('response',response);
                component.set("v.units",response);                
            }else if (state === "INCOMPLETE") {
                console.log('incomplete');
            }else if (state === "ERROR") {
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
    
    saveOrderPartner : function(component,event){
        console.log('saveOrderPartner');
        console.log('saveOrderPartner',component.find("purchaseOrder").get("v.value"));
        event.preventDefault();
        var action = component.get("c.saveOrder_Apex");
        action.setParams({"selectedOrderId" : component.get("v.recordId"),
                          "purchaseOrder" : component.find("purchaseOrder").get("v.value"),
                          "marketSegment" : component.find("marketSegment").get("v.value"),
                          "markSpecialInstructions" : component.find("markSpecialInstructions").get("v.value"),
                          "endCustomerId" : component.find("endCustomerId").get("v.value"),
                          "dealerStock" : component.find("dealerStock").get("v.value"),
                          "dealerComments" : component.find("dealerComments").get("v.value"),
                          "shipmentMethod" : component.find("shipmentMethod").get("v.value"),
                          "shippingAddress" : component.get("v.selectedShippingAddressId")});
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                /*console.log('success...about to navigate');
                var navEvt = $A.get("e.force:navigateToSObject");
                navEvt.setParams({
                    "recordId": component.get("v.recordId"),
                    "slideDevName": "detail"
                });
                navEvt.fire();*/
                $A.get('e.force:refreshView').fire();
                $A.get("e.force:closeQuickAction").fire()
            }else if (state === "INCOMPLETE") {
                console.log('incomplete');
            }else if (state === "ERROR") {
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
    
    hideOtherAssets : function(component,event){
        var action = component.get("c.hideOtherAssets_Apex");
        action.setParams({"selectedOrderId" : component.get("v.recordId")});
        action.setCallback(this, function(response) {
            var state = response.getState();
            if(state === "SUCCESS"){
                var response = response.getReturnValue();
                var amendurl;
                if(component.get("v.isCommunity")){
                    amendurl = $A.get("$Label.c.Community_Amendment_URL")+component.get("v.dealerId");
                }else{
                    amendurl = '/apex/sbqq__assetselectoramend?id='+component.get("v.dealerId");
                }
                window.open(amendurl,'_top');
            }else if(state === "INCOMPLETE") {
                console.log('incomplete');
            }else if(state === "ERROR"){
                var errors = response.getError();
                if(errors){
                    if(errors[0] && errors[0].message) {
                        console.log("Error message: " + errors[0].message);
                    }
                }else{
                    console.log("Unknown error");
                }
            }
        });
        $A.enqueueAction(action);
    },
    
    doOrderSave : function(component,event){
        this.showSpinner(component);
        event.preventDefault();        
        if (this.doValidate(component)) {        	
            let fields = event.getParam("fields");
            fields["NATT_Shipping_Address__c"] = component.get("v.selectedShippingAddressId");
            component.find('orderChangeForm').submit(fields);
        } else {
            this.hideSpinner(component);
        }
    }, 
    
    redirectToOrder : function(component,event) {
        
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": "Success!",
            "message": "Order was saved successfully.",
            "type": "success"
        });
        toastEvent.fire();
        
        var navEvt = $A.get("e.force:navigateToSObject");
        navEvt.setParams({
            "recordId": component.get("v.selectedOrderRecordId"),
            "slideDevName": "detail"
        });
        navEvt.fire();
    },
    
    showSpinner : function(cmp){
        cmp.set("v.isProcessing",true);
    },
    
    hideSpinner : function(cmp){
        cmp.set("v.isProcessing",false);
    },
    
    doValidate : function(cmp){
        if (!cmp.get("v.isEsolutions") && (!cmp.get("v.selectedShippingAddressId"))) {
            let toastEvent = $A.get("e.force:showToast");
            toastEvent.setParams({
                "title": "Address Required",
                "message": "Please select a shipping address.",
                "type" : "warning"
            });            
            toastEvent.fire();
            return false;
        } else {
            return true;
        }
    },
    
    displayError : function(cmp,msg){
        cmp.find('notifLib').showToast({
            "title": "Error",            
            "message": msg,
            "type":"error"
        });              
        this.hideSpinner(cmp);
    }
})