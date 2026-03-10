({
    init : function(component, event, helper) {
        
        helper.isJDESalesOrder_Null(component,event);
        helper.getOpenAmendmentOrderNumber(component,event);
        helper.hasOpenAmendment2(component,event);
        helper.hasOpenAmendment(component,event);
        // check user type
        helper.isCommunity(component, event);
        $A.util.removeClass(component.find("recordForm"),'slds-hide');
        
        // get shipment Method
        helper.getShipmentMethodEditable(component,event);
        
        // fetch related assets
        helper.fetchRelatedUnits(component,event);
        
    },
    next : function(component,event,helper){        
        component.set('v.showForm',true);        
        $A.util.removeClass(component.find("recordForm"),'slds-hide');
        $A.util.addClass(component.find("searchOrder"),'slds-hide');
        helper.getOpenAmendmentOrderNumber(component,event);
        helper.hasOpenAmendment2(component,event);
        helper.hasOpenAmendment(component,event);
    },
    
    doCancel : function(cmp,event,helper){
        $A.get("e.force:closeQuickAction").fire();
    },
    
    handleRecordUpdated : function(component,event,helper){
        
    },
    
    handleOnLoad : function(component,event,helper){
        const dealerId = component.find("dealerIdHidden").get("v.value");
        component.set("v.dealerId",dealerId);
        component.set("v.selectedShippingAddressId",component.find("shippingAddress").get("v.value"));
    },
    
    onEndCustomerChange : function(component,event,helper){
        component.set("v.endCustomerId",event.getParam("value").toString());
    }, 
    
    handleOnSuccess : function(component,event,helper){         
        const errorFlag = component.get("v.isError");        
        if(!errorFlag){
            helper.redirectToOrder(component,event);
        }
    },
    
    saveRequestedDate : function(component,event,helper){
        var rowIndex = event.getSource().get('v.name');        
        var orderlines = component.get("v.units");
        // call method to save new requested ship date
        helper.saveRequestedShipDateChanges(component,event,orderlines[rowIndex].orderItemId,orderlines[rowIndex].requestedShipDate);
    },  
    
    /*
    handleRequestedShipDate : function(component,event,helper){
        // validate requested ship date change
        helper.validateRequestedDatePriceChanges(component,event);
    },  */
    
    handleOnError : function(component,event,helper){
        helper.displayError(component,event.getParam('detail'));
    },
    
    handleSubmit : function(component,event,helper){
        helper.doOrderSave(component,event);
        component.set("v.isError",false);
    },
    
    handleReconfigureUnit : function(component,event,helper){
        helper.showSpinner(component);
        helper.hideOtherAssets(component,event);
    },
    
    saveOrderPartner : function(component,event,helper){        
        helper.saveOrderPartner(component,event);
    },
    
    handleComponentEvent : function(component, event, helper){         	 
        var selectedOrderGetFromEvent = event.getParam("recordByEvent");
        component.set("v.selectedRecord" , selectedOrderGetFromEvent);
        component.set("v.selectedOrderRecordId", selectedOrderGetFromEvent.Id);
        console.log('selectedOrderGetFromEvent',selectedOrderGetFromEvent);
        event.stopPropagation();
        
        // get shipment Method
        helper.getShipmentMethodEditable(component,event);
        
        // fetch related assets
        helper.fetchRelatedUnits(component,event);
    },
})