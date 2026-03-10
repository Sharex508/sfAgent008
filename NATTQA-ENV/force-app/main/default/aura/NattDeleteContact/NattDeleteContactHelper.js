({
	deleteContact : function(cmp) {
		let action = cmp.get("c.deleteContact");
        action.setParams({"recordId" : cmp.get("v.recordId")});
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {                  
                cmp.find('notifLib').showToast({
                    "title": "Success",            
                    "message": "Contact deleted."
                });                  
                if(response.getReturnValue()){
                    this.doRedirect(cmp);
                }else{
                	this.closeTab(cmp);
                }                
            }
            else if (state === "INCOMPLETE") {
                console.log('incomplete');
            }
            else if (state === "ERROR") {                
                cmp.find('notifLib').showToast({
                    "title": "Error",            
                    "message": response.getError()[0].message
                }); 
                $A.get("e.force:closeQuickAction").fire();
            }
        });
        $A.enqueueAction(action);
	},
    doRedirect : function(cmp){    
        $A.get("e.force:closeQuickAction").fire();
        var navService = cmp.find("navService");        
        var pageReference = {
            type: 'comm__namedPage',
            attributes: {                
                pageName: 'home'
            }
        };
        navService.navigate(pageReference);
    },
    closeTab : function(cmp){
        try
        {
            let workspaceAPI = cmp.find("workspace");
            workspaceAPI.getFocusedTabInfo().then(function(response) {
                let focusedTabId = response.tabId;
                workspaceAPI.closeTab({tabId: focusedTabId});
                $A.get('e.force:refreshView').fire();
            })
            .catch(function(error) {
                console.log('error caught: '+error);
                this.doRedirect(cmp);
            });
        }catch(error){
            var navService = cmp.find("navService");
            // Sets the route to /lightning/o/Account/home
            var pageReference = {
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'Contact',
                    actionName: 'home'
                }
            };
            navService.navigate(pageReference);
        }
    }
})