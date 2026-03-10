({
	processData : function(component, event, helper) {
        var action = component.get('c.deleteQuoteSnapshotRecords'); 
        action.setCallback(this, function(response){
            var state = response.getState(); // get the response state
            var error = response.getError();
            if(state == 'SUCCESS') {
                var reportURl = response.getReturnValue();
                var urlEvent = $A.get("e.force:navigateToURL");
                urlEvent.setParams({
                       "url": reportURl
                 });
                urlEvent.fire();
            }
        });
        $A.enqueueAction(action);
    }
})