({
    //Event call to close the quick action window
	closeQA : function(component, event, helper) {
		$A.get("e.force:closeQuickAction").fire();
	},
})