({
    fetchData: function (component) {
        const action = component.get("c.getOrderList");
        action.setCallback(this, function(response){
            const state = response.getState();
            if (state === "SUCCESS") {
                const rows = response.getReturnValue() || [];
                component.set("v.data", rows);           // important for viewDetails
                component.set("v.filteredData", rows);
            } else if (state === "ERROR") {
                const errs = response.getError();
                console.error('getOrderList error:', errs && errs[0] && errs[0].message);
        }
    });
    $A.enqueueAction(action);
},

    fetchTopData: function (component) {
        // Keep your signature where server expects a UserId (as in your Apex)
        const userId = $A.get("$SObjectType.CurrentUser.Id");
        const action = component.get("c.getTopOrderedItems");
        action.setParams({ UserId: userId });
        action.setCallback(this, function(response){
            const state = response.getState();
            if (state === "SUCCESS") {
                component.set("v.topBackorderData", response.getReturnValue() || []);
            } else if (state === "ERROR") {
                const errors = response.getError();
                console.error('getTopOrderedItems error:', errors && errors[0] && errors[0].message);
            }
    });
    $A.enqueueAction(action);
},

    viewDetails : function(event, action, component, row) {
        const navEvt = $A.get("e.force:navigateToSObject");
    navEvt.setParams({
        "recordId": row.Id,
        "slideDevName": "related"
    });
    navEvt.fire();
},

    getSearchResults : function(component) {
        const action = component.get("c.getResults");
    action.setParams({
            "orderNumber": component.get("v.filter"),
            "poNumber":    component.get("v.poNumber"),
            "partNumber":  component.get("v.partNumber"),
            "fromDate":    component.get("v.from"),
            "toDate":      component.get("v.to")
    });
    action.setCallback(this, function(response) {
            const rows = response.getReturnValue() || [];
            component.set('v.data', rows);
            component.set('v.filteredData', rows);
        });
    $A.enqueueAction(action);
    },

    sortData: function (component, fieldName, sortDirection) {
        const data = [...(component.get("v.filteredData") || [])];
        const isAsc = sortDirection === 'asc';
        data.sort(this.sortBy(fieldName, isAsc));
        component.set("v.filteredData", data);
    },

    sortBy: function (field, isAsc) {
        return function (a, b) {
            const va = a[field], vb = b[field];
            if (va === vb) return 0;
            if (va == null) return isAsc ? -1 : 1;
            if (vb == null) return isAsc ? 1 : -1;
            return (va > vb ? 1 : -1) * (isAsc ? 1 : -1);
        };
    },

    convertArrayOfObjectsToCSV: function(component, objectRecords) {
        let csvStringResult = '';
        try {
            const headers = {
                'Order_Date__c': 'Order Date',
                'Order_Number__c': 'Carrier Order #',
                'Purchase_Order_Number__c': 'PO #',
                'PartsNet__c': 'PartsNet #',
                'Parent_Order_Type__c': 'Order Type',
                'Part_Number__c': 'Part #',
                'Description__c': 'Part Descrption',
                'Quantity': 'Order Quantity',
                'NATT_Shipped_Quantity__c': 'Shipped Quantity',
                'NATT_Backordered_Quantity__c': 'Backorder Quantity',
                'Estimated_Availability__c': 'Estimated Availability',
                'NAC_Note__c': 'Note',
                'Total_Shipped_of_Total_Ordered__c': 'Total  Shipped of Total'
            };

        const columnDelimiter = ',';
        const lineDelimiter = '\r\n';
        const actualHeaderKey = Object.keys(headers);
        const headerToShow = Object.values(headers);
            csvStringResult += headerToShow.join(columnDelimiter) + lineDelimiter;

            const data = objectRecords || [];
            data.forEach(obj => {
                let line = '';
                actualHeaderKey.forEach(key => {
                    if (line !== '') line += columnDelimiter;
                    let strItem = obj[key] ? String(obj[key]) : '';
                    let newValueOfItem = strItem ? strItem.replace(/,/g, '') : strItem;

                    if (key === 'PartsNet__c') {
                        newValueOfItem = newValueOfItem ? '="' + newValueOfItem + '"' : newValueOfItem;
                    } else if (key === 'NATT_Shipped_Quantity__c') {
                        newValueOfItem = (newValueOfItem !== '' && newValueOfItem !== undefined && newValueOfItem !== null) ? newValueOfItem : '0';
                    }

                    line += newValueOfItem;
                });
                csvStringResult += line + lineDelimiter;
            });
        } catch (error) {
            console.error('error in convertArrayOfObjectsToCSV :::', error);
        }
        return csvStringResult;
    }
})