({    invoke : function(component, event, helper) {
   // Get the record ID attribute
   var record = component.get("v.recordid");
    
   // Get the Lightning event that opens a record in a new tab
   var redirect = $A.get("e.force:navigateToSObject");
    
   // Pass the record ID to the event
   redirect.setParams({
      "recordid": record
   });
         
   // Open the record
   redirect.fire();
}})