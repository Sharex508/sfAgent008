({
    init: function (component, event, helper) {

        component.set('v.columns',[
            {label: 'Order Date', fieldName: 'Order_Date__c', type: 'date', sortable: true, initialWidth: 100, cellAttributes: { alignment: 'center' },typeAttributes: {day: "numeric",month: "numeric",year: "numeric"} },
            
            {label: 'Carrier Order #', fieldName: 'Order_Number__c', type: 'text', sortable: true, initialWidth: 120, wrapText: true, cellAttributes: { alignment: 'center' } },
            {label: 'PO #', fieldName: 'Purchase_Order_Number__c', type: 'text', sortable: true, initialWidth: 100, cellAttributes: { alignment: 'center' } },
            {label: 'Order Type Name', fieldName: 'Parent_Order_Type__c', type: 'text', sortable: true, initialWidth: 120, cellAttributes: { alignment: 'center' } },
           // {label: 'Customer', fieldName: 'Customer__c', type: 'text', initialWidth: 200, cellAttributes: { alignment: 'center' } },
            {label: 'Part #', fieldName: 'Part_Number__c', type: 'text', sortable: true, initialWidth: 100, cellAttributes: { alignment: 'center' } },
            
            {label: 'Part Description', fieldName: 'Description__c', type: 'text', sortable: true, initialWidth: 185, cellAttributes: { alignment: 'center' } },
            //{label: 'Last Update', fieldName: 'Last_Update__c', type: 'date', sortable: true, initialWidth: 110, cellAttributes: { alignment: 'center' }, typeAttributes: {day: "numeric",month: "numeric",year: "numeric"} },
            {label: 'Remaining Qty', fieldName: 'NATT_Backordered_Quantity__c', type: 'text', sortable: true, initialWidth: 120, cellAttributes: { alignment: 'center' } },
            {label: 'Estimated Availability Date', fieldName: 'Estimated_Availability__c', type: 'text', sortable: true, initialWidth: 130, cellAttributes: { alignment: 'center' },typeAttributes: {day: "numeric",month: "numeric",year: "numeric"}  },
            {label: 'Note', fieldName: 'NAC_Note__c', type: 'text', initialWidth: 200, cellAttributes: { alignment: 'center' } },
            {label: 'Total Shipped of Total Ordered', fieldName: 'Total_Shipped_of_Total_Ordered__c', type: 'text', sortable: true, initialWidth: 170, cellAttributes: { alignment: 'center' } },
          //  {label: 'Ship to Name', fieldName: 'order.NATT_Shipping_Address__r.NATT_JDE_Alpha_Name__c', type: 'text', sortable: true, initialWidth: 170, cellAttributes: { alignment: 'center' } },

        ])
        helper.fetchData(component, 10);
        helper.fetchTopData(component);
    },

    handleRowAction: function (cmp, event, helper) {
        var action = event.getParam('action');
        var row = event.getParam('row');
        switch (action.name) {
            case 'view_details':
                helper.viewDetails(row, action, cmp, row);
                break;
        }
    },

    filter: function (component, event, helper) {
        helper.getSearchResults(component, event);
    },

    updateSorting: function (component, event, helper) {
        var fieldName = event.getParam('fieldName');
        var sortDirection = event.getParam('sortDirection');
        component.set("v.sortedBy", fieldName);
        component.set("v.sortedDirection", sortDirection);
        helper.sortData(component, fieldName, sortDirection);
    },

    clear: function (component, event, helper) {
        component.set("v.filter", null);
        component.set("v.poNumber", null);
        component.set("v.partNumber", null);
        component.set("v.from", null);
        component.set("v.to", null);
        helper.fetchData(component, 10);
    },

    downloadCsv : function(component, event, helper) {
        // get the Records [contact] list from 'ListOfContact' attribute
        var stockData = component.get("v.filteredData");

        // call the helper function which "return" the CSV data as a String
        var csv = helper.convertArrayOfObjectsToCSV(component, stockData);
        if (csv == null){return;}

        // ####--code for create a temp. <a> html tag [link tag] for download the CSV file--####
        //var hiddenElement = document.createElement('a');
        //hiddenElement.href = 'data:text/csv;charset=utf-8,' + encodeURI(csv);
        //hiddenElement.target = '_self'; //
        //hiddenElement.download = 'ExportData.csv';  // CSV file Name* you can change it.[only name not .csv]
        //document.body.appendChild(hiddenElement); // Required for FireFox browser
        //hiddenElement.click(); // using click() js function to download csv file
        
        const blob = new Blob([csv]);
        const exportedFilename = 'ExportData.csv';        
        const link = document.createElement("a");
        if(link.download !== undefined) {
            const url = URL.createObjectURL(blob);
            link.setAttribute("href", url);
            link.setAttribute("download", exportedFilename);
            link.style.visibility='hidden';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        }
    },

})