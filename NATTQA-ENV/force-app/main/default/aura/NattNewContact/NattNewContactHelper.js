({
    doInit : function(cmp) {
        let action = cmp.get("c.getRtId");
        action.setParams({"recordId" : cmp.get("v.recordId")});
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {                
                cmp.set("v.rtId",response.getReturnValue());                
            } else if (state === "INCOMPLETE") {
                console.log('incomplete');
            } else if (state === "ERROR") {
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
    displayError : function(cmp,msg){
        cmp.find('notifLib').showToast({
            "title": "Error",            
            "message": msg,
            "variant":"error"
        });              
        this.hideSpinner(cmp);
    }    
})