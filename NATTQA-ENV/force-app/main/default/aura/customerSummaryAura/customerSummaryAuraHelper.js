({
    closeModal : function(component) {
        $A.get("e.force:closeQuickAction").fire();
        $A.get('e.force:refreshView').fire();
    }
})