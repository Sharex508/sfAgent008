({
    doInit : function(component, event, helper) {
        let searchKeyValue;
        let pathArray = window.location.pathname.split('/');
        
        if(pathArray.includes('global-search')){
            searchKeyValue = pathArray[pathArray.length - 1];
            if(searchKeyValue.includes('Example%20search%20term')){
                return;
            }
        }
        
        else{
            component.set('v.isSearchButtonVisible', true);
        }
        
        if(searchKeyValue){
            helper.doCallout(component, event, helper, searchKeyValue);     
        }
    },
    
    handleClick : function(component, event, helper) {
        let searchKeyValue = component.find("searchID").get("v.value");
        helper.doCallout(component, event, helper, searchKeyValue);
    },
    handlePrint : function(component, event, helper) {
        let searchKeyValue1 = component.find("searchID").get("v.value");
        if(searchKeyValue1 != null){
			var url = '/apex/NATT_Generate_PDF?searchKeyValue1=' +searchKeyValue1;
        	console.log(url);
            window.open(url);}
    },
})