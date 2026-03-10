({
    //Datatable Columns properties congiguration 
    fetchArticles: function(component, event, helper) {
        component.set('v.articlecolumns', [
            {  label: '',fieldName: 'recCount',type: "number", initialWidth: 12, hideLabel: true, hideDefaultActions: true,
             cellAttributes: { alignment: 'center', class: 'cellheight' }
            },
            {  label: 'Title',fieldName: 'titleLink',type: 'url', sortable :true, hideDefaultActions: true,
             typeAttributes: {
                 label: {
                     fieldName: 'Title'
                 },
                 tooltip:{
                     fieldName: 'titleToolTip'
                 },
                 target: '_blank'
             },
             cellAttributes: {class: 'cellheight' }
            },
            {  label: 'Doc Number',fieldName: 'docNumber',type: "text",sortable :true, cellAttributes: {class: 'cellheight' } },
            {  label: 'Department',fieldName: 'department',type: "text",sortable :true, cellAttributes: {class: 'cellheight' }},
            {  label: 'Segment',fieldName: 'segment',type: 'text',sortable :true, cellAttributes: {class: 'cellheight' }},
            {  label: 'Document Type',fieldName: 'docType',type: 'text',sortable :true, cellAttributes: {class: 'cellheight' }},
            {  label: 'Last Modified Date',fieldName: 'lstModDate',type: 'date',sortable :true,
             typeAttributes:{year:'numeric',month:'numeric',day:'numeric',
                             hour:'2-digit',minute:'2-digit',hour12:true},
             cellAttributes: {class: 'cellheight' }
            }
        ]);
    },
    
    //Call helper method for column data sorting
    handleSort: function(component,event,helper){
        var sortBy = event.getParam("fieldName");
        var sortDirection = event.getParam("sortDirection");
        
        component.set("v.sortBy",sortBy);
        component.set("v.sortDirection",sortDirection);
        
        //helper method to sort column data asc/desc
        helper.sortData(component,sortBy,sortDirection);
    },
    
    //call helper method on Search Event Fire
    spinnerEvt : function(component, event, helper){
        component.set("v.spinnerEnabled", true);
    },
    
    //call helper method on Search Event Fire
    getArticles : function(component, event, helper){
        component.set("v.recordCount", 0);
        helper.getArticles(component, event, helper);
                
    }
})