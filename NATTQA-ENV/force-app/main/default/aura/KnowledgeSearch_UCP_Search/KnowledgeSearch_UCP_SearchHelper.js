({
    //Get picklist values on component load 
    doInit : function(component, event, helper) {
        component.set("v.spinnerEnabled", true);
        var action = component.get('c.getPickList');
        action.setCallback(this,function(result){
            var state = result.getState();
            if (state === "SUCCESS"){
                var resultValue = result.getReturnValue();
                //get and set the picklist values from Knowledge Objects
              //  component.set("v.departmentList", resultValue.department);
                component.set("v.segmentList", resultValue.segment);
                component.set("v.docTypeList", resultValue.documentType);
            }
            component.set("v.spinnerEnabled", false);
        });
        $A.enqueueAction(action);
    },
    
    //Search Articles based on user inputs
    searchArticles : function(component, event, helper) {
        var userinput = component.find("searchKnowledge").get("v.value");
        if(component.get("v.toggleExpand")){
            var title = component.find("title").get("v.value");
            var docNumber = component.find("docNumber").get("v.value");
           // var department = component.find("department").get("v.value");
            var segment = component.find("segment").get("v.value");
            var docType = component.find("docType").get("v.value");
        }
        
        if (userinput || title || docNumber || segment ||docType){
            var appEvent = $A.get("e.c:KnowledgeSearch_REF_SpinerEvent"); 
            appEvent.fire();
            
            var action = component.get("c.getArticleList");
            action.setParams({ 
                userinput : userinput,
                title : title,
                docNumber : docNumber,
                //department : department,
                segment : segment,
                docType : docType
            });
            
            action.setCallback(this, function(response) {
                var state = response.getState();
                var error = response.getError();
                if (state === "SUCCESS"){
                    var records = response.getReturnValue();
                    var appEvent = $A.get("e.c:KnowledgeSearch_REF_AppEvent"); 
                    //Set event attribute value
                    appEvent.setParams({"acticleList" : records}); 
                    appEvent.fire();
                }
            });
            $A.enqueueAction(action);  
        }
        component.set("v.spinnerEnabled", false);
    }
})