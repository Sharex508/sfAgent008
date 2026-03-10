({
    helperMethod : function() {

    },
    toastMessageMethod: function(component, errorMessage){
        console.log('error message toast');
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": "Error!",
            "message": 'Test Error',
            "type": "error"
        });
        toastEvent.fire();
    },

    gotoURL : function (component) {
        var urlEvent = $A.get("e.force:navigateToURL");
        urlEvent.setParams({
          "url": "./"
        });
        urlEvent.fire();
    },

    showNoticeMethod : function (component, errorTitle, errorMessage){
        component.find('notifLib').showNotice({
            "variant": "warning",
            "header": errorTitle,
            "message": errorMessage,
        });
    }
})