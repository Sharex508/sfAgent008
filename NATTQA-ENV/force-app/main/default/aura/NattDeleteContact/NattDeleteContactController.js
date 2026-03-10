({
	doInit : function(cmp, event, helper) {
		helper.deleteContact(cmp);
	},
    handleRedirect : function(cmp,event,helper){
    	helper.doRedirect(cmp);
	},
    handleConfirmDialogYes : function(cmp, event, helper) {
        helper.deleteContact(cmp);
    },     
    handleConfirmDialogNo : function(cmp, event, helper) {
        $A.get("e.force:closeQuickAction").fire();
    }
})