({
    doCallout : function(component, event, helper, searchKeyValue) {
        component.set('v.unitDetails', '');
        component.set('v.majorCmp', '');
        component.set('v.warrantyCoverage', '');
        component.set('v.fieldAction', '');
        component.set('v.claims', '');
        component.set('v.upComingSchedules', '');
        component.set('v.recordExist', false);
        
        if(searchKeyValue === null || searchKeyValue === undefined || searchKeyValue === ''){
            component.find('notifLib').showToast({
                "title": "Error!",
                "message": "Please enter serial number"
            });
            return;
        }
        
        if(searchKeyValue.length < 5){
            component.find('notifLib').showToast({
                "title": "Error!",
                "message": "Please enter serial number with more than 5 characters"
            });
            return;
        }
        
        component.set('v.isLoading', true); //to start loading
        
        let action = component.get("c.doCallout");
        action.setParams({ searchKey : searchKeyValue });
        
        action.setCallback(this, function(response) {
            let state = response.getState();
            
            if (state === "SUCCESS") {
                let returnValue = response.getReturnValue();
                
                if(returnValue.length === 0){
                    component.find('notifLib').showToast({
                        "title": "Error!",
                        "message": "No record found, please try with another serial number"
                    });
                    component.set('v.isLoading', false); // to stop loading
                    return;
                }
                
                component.set('v.responseData',returnValue);
                
                let majorCmpLst,unitDetails,warrantyCovergae,fieldActions,
                    claims,upComingSchedule = {};
                
                for(let key in returnValue){
                    unitDetails =  returnValue[key].unit;
                    majorCmpLst = returnValue[key].majorComponents;
                    warrantyCovergae = returnValue[key].warrantyCoverages;
                    fieldActions = returnValue[key].fieldActions;
                    claims = returnValue[key].claims;
                    upComingSchedule = returnValue[key].upcomingSchedules;
                }
                
                component.set('v.unitDetails', unitDetails);
                component.set('v.majorCmp', majorCmpLst);
                component.set('v.warrantyCoverage', warrantyCovergae);
                component.set('v.fieldAction', fieldActions);
                component.set('v.claims', claims);
                component.set('v.upComingSchedules', upComingSchedule);
                
                component.set('v.recordExist', true);
                component.set('v.isLoading', false); // to stop loading
                
            }
            else if (state === "ERROR") {
                component.set('v.recordExist', false);
                let errors = response.getError();
                if (errors) {
                    if (errors[0] && errors[0].message) {
                        console.log("Error message: ", errors[0].message);
                    }
                } else {
                    console.log("Unknown error");
                }
            }
        });
        $A.enqueueAction(action);
    }
})