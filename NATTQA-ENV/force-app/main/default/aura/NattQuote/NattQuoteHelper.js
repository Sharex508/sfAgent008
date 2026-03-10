({
    doInit : function(cmp) {
        let recordId = cmp.get("v.recordId");        
        if(recordId.startsWith('006')){
            cmp.set("v.showPrimaryField", true);
            this.getOpportunityData(cmp);
            this.getInternalUser(cmp);
        }else{
            cmp.find("dealerId").set("v.value",recordId);
            cmp.find("stageName").set("v.value","Quoting");
            cmp.set("v.recordId","");            
            this.getIdData(cmp);
            //$A.util.addClass(cmp.find("fieldDiv"),'slds-hide');
        }
    },
    
    getIdData : function(cmp){
        let action = cmp.get("c.getData");
        action.setParams({"accountId" : cmp.find("dealerId").get("v.value")});
        action.setCallback(this, function(response) {
            let state = response.getState();
            if (state === "SUCCESS") {
                let responseWrapper = response.getReturnValue();
                //CTBR changes
                let hasCTBRBluEdge = responseWrapper.oppRtList.some(function(item) {
                return item.label === "CTBR BluEdge";
               });
 
            if (hasCTBRBluEdge) {
            // Remove the object with label "CTBR BluEdge"
              responseWrapper.oppRtList = responseWrapper.oppRtList.filter(function(item) {
                return item.label !== "CTBR BluEdge";
            });
        }
                cmp.set("v.wrap",responseWrapper);
                //Cmp.set("v.pbId",responseWrapper.defaultPbId);\
                cmp.set("v.pbMap",responseWrapper.nattPbMap);
                cmp.find("dealerId").set("v.value",responseWrapper.dealerId);
                cmp.find("endCustomerId").set("v.value",responseWrapper.endCustomerId);
                cmp.set("v.dealerId",responseWrapper.dealerId);
                cmp.set("v.endCustomerId",responseWrapper.endCustomerId);
                //Mahesh changes
                if(!responseWrapper.isCTBRUnit){
                cmp.set("v.selectedBillingAddressId",responseWrapper.defaultBillingAddressId);
                }
                //Cmp.set("v.selectedRtId",responseWrapper.defaultRtId);
                cmp.set("v.isEsolutions",responseWrapper.isEsolutions);
                cmp.set("v.isBluEdge",responseWrapper.isBluEdge);
                console.log('Get isCTMUnit' + responseWrapper.isCTMUnit);
                cmp.set("v.isCTMUnit",responseWrapper.isCTMUnit);
                cmp.set("v.isCTBRUnit",responseWrapper.isCTBRUnit);
                cmp.set("v.isCTBRBluEdge",responseWrapper.isCTBRBluEdge);
                cmp.set("v.isDirectSale",responseWrapper.isDirectSale);
                cmp.set("v.countryOptions",responseWrapper.countryOptions);
                cmp.set("v.stateOptions",responseWrapper.stateOptions);
                cmp.set("v.dirSalesQuoteRtId",responseWrapper.dirSalesQuoteRtId);
                cmp.set("v.isInternalUser",responseWrapper.isInternalUser);
            }
            else if (state === "INCOMPLETE") {
                
            }
                else if (state === "ERROR") {
                    let errors = response.getError();
                    if (errors) {
                        if (errors[0] && errors[0].message) {
                           // console.log("Error message: " + errors[0].message);
                        }
                    } else {
                    }
                }
        });
        $A.enqueueAction(action);
    },
    getOpportunityData : function(cmp){
        let action = cmp.get("c.getOppData");
        action.setParams({oppId : cmp.get("v.recordId")});
        action.setCallback(this, function(response) {
            let state = response.getState();
            if (state === "SUCCESS") {
                cmp.set("v.opp",response.getReturnValue());
                cmp.set("v.selectedShippingAddressId",response.getReturnValue().NATT_Shipping_Address__c);
                cmp.set("v.selectedBillingAddressId",response.getReturnValue().NATT_Billing_Address__c);
                let label = response.getReturnValue().SBQQ__PrimaryQuote__r.RecordType.Name;
                if(label=='BluEdge'){                    
                    cmp.set("v.isBluEdge",true);
                } else if(label.includes('Lynx Fleet')){                    
                    cmp.set("v.isEsolutions",true);
                } else if(label.includes('CTBR Units')){                    
                    cmp.set("v.isCTBRUnit",true);
                } else if(label==='CTBR BluEdge'){                    
                    cmp.set("v.isCTBRBluEdge",true);
                } else if(label.includes('MX Units') || label.includes('CTM Units')){            
                    cmp.set("v.isCTMUnit",true);
                }
                cmp.set("v.hasSelectedRt",true);
                $A.util.removeClass(cmp.find("fieldDiv"),'slds-hide');
            }
            else if (state === "INCOMPLETE") {
            }
                else if (state === "ERROR") {
                    let errors = response.getError();
                    if (errors) {
                        if (errors[0] && errors[0].message) {
                           // console.log("Error message: " + errors[0].message);
                        }
                    } else {
                    }
                }
        });
        $A.enqueueAction(action);
    },
    doCreate : function(cmp,event){
        try{
            this.showSpinner(cmp);
            event.preventDefault();        
            if (this.doValidate(cmp)) {        	
                let fields = event.getParam("fields");
           if(!cmp.get("v.isCTBRUnit")){
            fields["NATT_Shipping_Address__c"]=cmp.get("v.selectedShippingAddressId");
            fields["NATT_Billing_Address__c"]=cmp.get("v.selectedBillingAddressId");
            }
                fields["RecordTypeId"]=cmp.get("v.selectedRtId");
                if(cmp.get("v.recordId")==''){
                    fields["Pricebook2Id"]=cmp.get("v.wrap").rtToPbMap[cmp.get("v.selectedRtId")];
                }
                var quoteObj = {
                    MarkForCountry : cmp.get("v.MarkForCountry"),
                    MarkForState : cmp.get("v.MarkForState"),
                    MarkForCity : cmp.get("v.MarkForCity"),
                    poNumber : cmp.get("v.poNumber"),
                //HasFreight : cmp.get("v.HasFreight")
            };
            cmp.find('createForm').submit(fields);
            
            } else {
                this.hideSpinner(cmp);
            }
        }
        catch(error){
            console.error('Exception here ===>'+JSON.stringify(error));
        }
    },    
    showSpinner : function(cmp){
        cmp.set("v.isProcessing",true);
    },
    hideSpinner : function(cmp){
        cmp.set("v.isProcessing",false);
    },
    doValidate : function(cmp){
        console.log('end Customer --'+ cmp.get("v.endCustomerId"));
        console.log('Stock --'+ cmp.get("v.stock"));
        
        if((cmp.get("v.isBluEdge") || (!cmp.get("v.isBluEdge") && !cmp.get("v.isEsolutions") && !cmp.get("v.isCTBRUnit") && !cmp.get("v.isCTBRBluEdge"))) && (cmp.get("v.endCustomerId") == null && !cmp.get("v.stock"))){
            let toastEvent = $A.get("e.force:showToast");
            toastEvent.setParams({
                "title": "End Customer or Stock Required",
                "message": "Select an End Customer or check the Stock field.",
                "type" : "warning"
            });            
            toastEvent.fire();
            return false;
        }
        if ((!cmp.get("v.isEsolutions") && !cmp.get("v.isCTMUnit")) && (!cmp.get("v.selectedBillingAddressId") || !cmp.get("v.selectedShippingAddressId"))) {
            let toastEvent = $A.get("e.force:showToast");
            toastEvent.setParams({
                "title": $A.get("$Label.c.AddressRequiredErrorMessage"),
                "message": $A.get("$Label.c.AddressErrorMessage"),
                "type" : "warning"
            });            
            toastEvent.fire();
            return false;
        }
        return true;
    },
    createQuote : function(cmp,event){
        let record = event.getParam("response");
        let primaryQuote = cmp.get("v.showPrimaryField") ? document.getElementById("primaryQuote").checked : true;            
        let action = cmp.get("c.createQuote");
        let quoteObj = {
            MarkForCountry : cmp.get("v.MarkForCountry"),
            MarkForState : cmp.get("v.MarkForState"),
            MarkForCity : cmp.get("v.MarkForCity"),
            poNumber : cmp.get("v.poNumber"),
            	hasFreight : cmp.get("v.HasFreight"),
            shippingAddress : cmp.get("v.selectedShippingAddressId"),
            billingAddress : cmp.get("v.selectedBillingAddressId")
        };
        console.log('quote-'+ JSON.stringify(quoteObj));
        action.setParams({oppId : record.id,
                          primaryQuote: primaryQuote,
                          quoteJSON :JSON.stringify(quoteObj)
                         });
        
        action.setCallback(this, function(response) {
            let state = response.getState();
            if (state === "SUCCESS") {
                let navService = cmp.find("navService");                
                let pageReference = {
                    type: 'standard__recordPage',
                    attributes: {
                        objectApiName: 'SBQQ__Quote__c',
                        actionName: 'view',
                        recordId: response.getReturnValue()
                    }
                };
                navService.navigate(pageReference,true);
            }
            else if (state === "INCOMPLETE") {
                this.hideSpinner(cmp);
            }
                else if (state === "ERROR") {
                    let errors = response.getError();
                    if (errors) {
                        if (errors[0] && errors[0].message) {
                            this.displayError(cmp,errors[0].message);
                        }
                    } else {
                        this.displayError(cmp,'Unknown error.');
                    }
                    this.hideSpinner(cmp);
                }
        });
        $A.enqueueAction(action);
        
    },
    
    displayError : function(cmp,msg){
        cmp.find('notifLib').showToast({
            "title": "Error",            
            "message": msg
        });              
        this.hideSpinner(cmp);
    },
})