({
	init : function(cmp, event, helper) {
		let navService = cmp.find("navService");
        let pageReference = {
            type: 'standard__recordPage',
            attributes: {
                recordId : cmp.get('v.recId'),
                actionName: 'view'
            }
        };
        $A.get('e.force:refreshView').fire();
        navService.navigate(pageReference,true);        
	}
})