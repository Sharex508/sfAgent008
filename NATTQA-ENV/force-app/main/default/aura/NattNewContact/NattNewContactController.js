({
    doInit : function(cmp, event, helper) {
        helper.doInit(cmp);
    },
    handleOnLoad : function(cmp,event,helper){
        cmp.find("account").set("v.value",cmp.get("v.recordId"));
        cmp.find("rtId").set("v.value",cmp.get("v.rtId"));
        helper.doInit(cmp);
    }, 
    handleCreation : function(cmp,event,helper){
        cmp.set("v.createdContactId",event.getParam("response").id);  
        cmp.find('notifLib').showToast({
            "title": "Success",            
            "message": "Contact created."
        });        
        $A.get("e.force:closeQuickAction").fire();
    },    
    handleRedirect : function(cmp,event,helper){        
        let contactId = cmp.get("v.createdContactId");
        console.log('redirect called with: '+contactId);
        let navService = cmp.find("navService");
        let pageReference = {    
            "type": "standard__recordPage", 
            "attributes": {
                "recordId": contactId,
                "actionName": "edit"
            }
        }
        navService.navigate(pageReference);
    },
    handleOnError : function(cmp,event,helper){
        helper.displayError(cmp,event.getParam('detail'));
    },
    
})