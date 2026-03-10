({
    init: function (component, event, helper) {
        component.set('v.columns', [
            {cellAttributes:{alignment:'center'}, fieldName:'Order_Number__c', initialWidth:200, label:$A.get("$Label.c.NATT_Backorder_Report_Carrier_Order"), sortable:true, type:'text', wrapText:true },
            {cellAttributes:{alignment:'center'}, fieldName:'Description__c',   initialWidth:185, label:$A.get("$Label.c.NATT_Backorder_Report_Part_Description"), sortable:true, type:'text' },
            {cellAttributes:{alignment:'center'}, fieldName:'Customer__c',      initialWidth:200, label:$A.get("$Label.c.NATT_Backorder_Report_Customer"), type:'text' },
            {cellAttributes:{alignment:'center'}, fieldName:'Order_Date__c',    initialWidth:200, label:$A.get("$Label.c.NATT_Backorder_Report_Order_Date"), sortable:true, typeAttributes:{day:"numeric", month:"numeric", year:"numeric"}, type:'date' },
            {cellAttributes:{alignment:'center'}, fieldName:'Purchase_Order_Number__c', initialWidth:200, label:$A.get("$Label.c.NATT_Backorder_Report_PO"), sortable:true, type:'text' },
            {cellAttributes:{alignment:'center'}, fieldName:'Part_Number__c',   initialWidth:200, label:$A.get("$Label.c.NATT_Backorder_Report_Part"), sortable:true, type:'text' },
            {cellAttributes:{alignment:'center'}, fieldName:'NATT_Backordered_Quantity__c', initialWidth:200, label:$A.get("$Label.c.NATT_Backorder_Report_Remaining_Qty"), sortable:true, type:'text' },
            {cellAttributes:{alignment:'center'}, fieldName:'Total_Shipped_of_Total_Ordered__c', initialWidth:200, label:$A.get("$Label.c.NATT_Backorder_Report_Total_Shipped_of_Total_Ordered"), sortable:true, type:'text'}
        ]);
        helper.fetchData(component);
        helper.fetchTopData(component);
    },

    handleRowAction: function (cmp, event, helper) {
        const action = event.getParam('action');
        const row = event.getParam('row');
        if (action && action.name === 'view_details') {
                helper.viewDetails(row, action, cmp, row);
        }
    },
       
    filter: function (component, event, helper) {
        helper.getSearchResults(component);
    },

    updateSorting: function (component, event, helper) {
        const fieldName    = event.getParam('fieldName');
        const sortDirection = event.getParam('sortDirection');
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
        helper.fetchData(component);
    },

    downloadCsv : function(component, event, helper) {
        const stockData = component.get("v.filteredData") || [];
        const csv = helper.convertArrayOfObjectsToCSV(component, stockData);
        if (!csv) return;

        const blob = new Blob([csv]);
        const exportedFilename = 'ExportData.csv';
        const link = document.createElement("a");
        if (link.download !== undefined) {
            const url = URL.createObjectURL(blob);
            link.setAttribute("href", url);
            link.setAttribute("download", exportedFilename);
            link.style.visibility = 'hidden';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        }
    }
})