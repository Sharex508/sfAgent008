({
    //Call helper method on Component load
    doInit : function(component, event, helper) {
        helper.doInit(component, event, helper);
    },
    
    //Call helper method on Search button click 
    searchArticles : function(component, event, helper) {
        helper.searchArticles(component, event, helper);
    },
    
    
    //Method to expand user input section and change button icon on click
    toggleSection : function(component, event, helper) {
        var toggleExpand = component.get("v.toggleExpand");
        if(toggleExpand){
            component.set("v.toggleExpand", false);
            component.set("v.buttonIcon", 'utility:jump_to_bottom');
        }else{
            component.set("v.toggleExpand", true);
            component.set("v.buttonIcon", 'utility:jump_to_top');
        }
    },
    
    //Onkeypress Event to trigge the search on Enter
    handleKeyUp : function(component, event, helper){
        if (event.keyCode === 13) {
            helper.searchArticles(component, event, helper);
        }
    },
    
    clearSearch : function(component, event, helper){
        var toggleEnabled = component.get("v.toggleExpand");
        
        component.find("searchKnowledge").set("v.value", '');
        if(toggleEnabled){
            component.find("title").set("v.value", '');
            component.find("docNumber").set("v.value", '');
            component.find("department").set("v.value", '');
            component.find("segment").set("v.value", '');
            component.find("docType").set("v.value", '');
        }
        
        //Event to clear search result screen
        var appEvent = $A.get("e.c:KnowledgeSearch_REF_AppEvent"); 
        //Set event attribute value
        appEvent.setParams({"acticleList" : null}); 
        appEvent.fire();
    },
})