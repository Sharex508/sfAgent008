({
	doInit : function(cmp, event, helper) {
		helper.deleteAccount(cmp);
	},
    handleRedirect : function(cmp,event,helper){
    	helper.doRedirect(cmp);
	},
    handleConfirmDialogYes : function(cmp, event, helper) {
        helper.deleteAccount(cmp);
    },     
    handleConfirmDialogNo : function(component, event, helper) {
        $A.get("e.force:closeQuickAction").fire();
    }
})