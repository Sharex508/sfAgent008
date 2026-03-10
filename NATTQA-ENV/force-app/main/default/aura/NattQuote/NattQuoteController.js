/* eslint-disable object-shorthand */
({
    doInit : function(cmp, event, helper) {
        if(cmp.get("v.CTBRBuleEdgeRecordCommunity")){
            }else
        helper.doInit(cmp);
        
    },
    doCancel : function(cmp,event,helper){
        $A.get("e.force:closeQuickAction").fire();
    },
    onDealerChange : function(cmp,event,helper){
        cmp.set("v.dealerId",event.getParam("value").toString());
    },
    onEndCustomerChange : function(cmp,event,helper){
        cmp.set("v.endCustomerId",event.getParam("value").toString());
    },
    onstockChange : function(cmp,event,helper){
        cmp.set("v.stock",!cmp.get("v.stock"));
    },    
    //CTBR Changes
    handleShippingAddressChange : function(cmp,event,helper){
        
        cmp.set("v.nattShipAddress",event.getParam("value").toString());
    },
	handleBillingAddressChange : function(cmp,event,helper){
        
        cmp.set("v.nattBillAddress",event.getParam("value").toString());
    },
    handleOnLoad : function(cmp,event,helper){
        let dealerId = cmp.find("dealerId").get("v.value");
        cmp.set("v.dealerId",dealerId);
        cmp.set("v.quoteFields",{'SBQQ__Account__c':dealerId,'NATT_Shipping_Address__c':'','NATT_Billing_Address__c':''});
        
    },
    handleOnSuccess : function(cmp,event,helper){
        helper.createQuote(cmp,event);
    },
    handleOnError : function(cmp,event,helper){
        helper.displayError(cmp,event.getParam('detail'));
    },
    handleSubmit : function(cmp,event,helper){        
        helper.doCreate(cmp,event);
    },
    handleRadioChange : function(cmp,event,helper){
        cmp.set("v.selectedRtId",event.getParam("value"));
        let label = cmp.get("v.wrap").oppRtMap[event.getParam("value")];
        cmp.set("v.isEsolutions",false);
        cmp.set("v.isBluEdge",false);
        cmp.set("v.isCTMUnit",false);
        cmp.set("v.isCTBRUnit",false);
        cmp.set("v.isCTBRBluEdge",false);
        cmp.set("v.isNATTUnit",false);
        if(label==='BluEdge'){        
            cmp.set("v.isBluEdge",true);
        } else if(label.includes('Lynx Fleet')){            
            cmp.set("v.isEsolutions",true);
        } else if(label.includes('CTBR Units')){            
            cmp.set("v.isCTBRUnit",true);
        } else if(label==='CTBR BluEdge'){            
            cmp.set("v.isCTBRBluEdge",true);
        } else if(label.includes('MX Units') || label.includes('CTM Units') || label.includes('CTM BluEdge')){            
            cmp.set("v.isCTMUnit",true);
        }
            
        
    },
    handlePicklistChange: function(component, event, helper) {
        let inputFieldCmp = event.getSource();
        let fieldName = inputFieldCmp.get("v.fieldName");
        let selectedValue = inputFieldCmp.get("v.value");
        
        if (fieldName === "Mark_For_Location_Country__c") {
            component.set("v.MarkForCountry", selectedValue);
        } else if (fieldName === "Mark_For_Location_State__c") {
            component.set("v.MarkForState", selectedValue);
        } else if (fieldName === "Mark_For_Location_City__c") {
            component.set("v.MarkForCity", selectedValue);
        } else if (fieldName === "NATT_Purchase_Order__c") {
            component.set("v.poNumber", selectedValue);
        } else if (fieldName === "NATT_Has_Freight__c"){
            component.set("v.HasFreight",selectedValue);
        }

    },

    doNext : function(cmp,event,helper){
        let selectedRTID=cmp.get("v.selectedRtId");
        if(selectedRTID===undefined || selectedRTID==='' || selectedRTID==null){
            alert('Please select atleast one record type');
            return;
        }
        cmp.set("v.hasSelectedRt",true);
        $A.util.removeClass(cmp.find("fieldDiv"),'slds-hide');
        }
  })