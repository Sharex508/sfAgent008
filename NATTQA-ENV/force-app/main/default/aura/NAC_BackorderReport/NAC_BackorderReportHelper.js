({
fetchData: function (component, fetchData, numberOfRecords) {
    var action = component.get("c.getOrderList");
    action.setParams({
    });
    action.setCallback(this, function(response){
        var state = response.getState();
        if (state === "SUCCESS") {
            var records = response.getReturnValue();
            component.set("v.filteredData", response.getReturnValue());
            records.forEach(function(record){
                //    record.linkName = 'https://carrier-global--ttcgidv1.lightning.force.com//'+record.Id;
            })
        }
    });
    $A.enqueueAction(action);
},

fetchTopData: function (component) {
    var userId = $A.get("$SObjectType.CurrentUser.Id");
    var action = component.get("c.getTopOrderedItems");
    action.setParams({ UserId: userId});
    action.setCallback(this, function(response){
        var state = response.getState();
        console.log('State: ' + state);
        if (state === "SUCCESS") {
            // var records = response.getReturnValue();
            // console.log('records value: ' + records);
            // console.log('UserId: ' + userId);
            var map = response.getReturnValue();
            var pdt = map[0].quantity;
            console.log('pdt: ' + pdt);
            
            component.set("v.topBackorderData", response.getReturnValue());
        }
        else if(state == "ERROR"){
            var errors = response.getError();                       
            console.log('Errors: ' + errors[0].message);
        }
        
    });
    $A.enqueueAction(action);
},

viewDetails : function(event, action, component, row) {
    var rows = component.get('v.data');
    var rowIndex = rows.indexOf(row);
    var recId = component.get("v.recordId");
    var navEvt = $A.get("e.force:navigateToSObject");
    navEvt.setParams({
        "recordId": row.Id,
        "slideDevName": "related"
    });
    navEvt.fire();
},

getSearchResults : function(component, event) {
    
    var orderNumber = component.get("v.filter");
    var poNumber = component.get("v.poNumber");
    var partNumber = component.get("v.partNumber");
    var toDate = component.get("v.to");
    var fromDate = component.get("v.from");
    
    console.log('filter Value: ' + orderNumber);
    console.log('po Value: ' + poNumber);
    console.log('part Value: ' + partNumber);
    console.log('from Value: ' + fromDate);
    console.log('to Value: ' + toDate);
    
    var action = component.get("c.getResults");
    
    var self = this;
    action.setParams({
        "orderNumber":orderNumber,
        "poNumber":poNumber,
        "partNumber":partNumber,
        "fromDate":fromDate,
        "toDate":toDate
    });
    
    action.setCallback(this, function(response) {
        component.set('v.data', response.getReturnValue());
        component.set('v.filteredData', response.getReturnValue());            
    } );
    $A.enqueueAction(action);
    
    
},

sortData: function (component, fieldName, sortDirection) {
    var fname = fieldName;
    var data = component.get("v.filteredData");
    var reverse = sortDirection !== 'asc';
    data.sort(this.sortBy(fieldName, reverse))
    component.set("v.filteredData", data);
},
sortBy: function (field, reverse) {
    var key = function(x) {return x[field]};
    reverse = !reverse ? 1 : -1;
    return function (a, b) {
        return a = key(a), b = key(b), reverse * ((a > b) - (b > a));
    }
},

convertArrayOfObjectsToCSV: function(component, objectRecords) {
    let csvStringResult = '';
    try {
        let jsonObject = JSON.stringify(objectRecords);        
        
        let headers = {
            'Order_Date__c': 'Order Date',
            'Order_Number__c': 'Carrier Order'.replace('Carrier Order', 'Carrier Order #'),
            'Purchase_Order_Number__c': 'PO'.replace('PO','PO #'),
           // 'Customer__c': 'Customer',
            'PartsNet__c': 'PartsNet'.replace('PartsNet', 'PartsNet #'),
            'Parent_Order_Type__c': 'Order Type',
            'Part_Number__c': 'Part'.replace('Part','Part #'),
            'Description__c': 'Part Descrption',
            'Quantity': 'Order Quantity',
            'NATT_Shipped_Quantity__c': 'Shipped Quantity',
            'NATT_Backordered_Quantity__c': 'Backorder Quantity',
            'Estimated_Availability__c': 'Estimated Availability',
            'NAC_Note__c': 'Note',
            'Total_Shipped_of_Total_Ordered__c': 'Total  Shipped of Total',
            //  'order.NATT_Shipping_Address__r.NATT_JDE_Alpha_Name__c': 'Ship To Name'
        };
        
        const columnDelimiter = ',';
        const lineDelimiter = '\r\n';
        const actualHeaderKey = Object.keys(headers);
        const headerToShow = Object.values(headers);
        
        
        csvStringResult += headerToShow.join(columnDelimiter);
        csvStringResult += lineDelimiter;
        const data = typeof jsonObject !=='object' ? JSON.parse(jsonObject) : jsonObject;
        
        data.forEach(obj=>{
            let line ='';
            actualHeaderKey.forEach(key=> {
            if(line !== '') {
                line+=columnDelimiter;
            }
                        
            let strItem = obj[key] ? obj[key]+'': '';
            let newValueOfItem = strItem ? strItem.replace(/,/g, ''):strItem;
        
            if (key === 'PartsNet__c') {
                newValueOfItem = newValueOfItem ? '="' + newValueOfItem + '"' : newValueOfItem;
            }
            else if( key === 'NATT_Shipped_Quantity__c'){
                newValueOfItem = newValueOfItem !== '' &&  newValueOfItem  !== undefined &&  newValueOfItem  !== null ? newValueOfItem : '0';
            }
            line += newValueOfItem;
        });
    
        csvStringResult += line+lineDelimiter;
        });
    } catch (error) {
        console.error('error in convertArrayOfObjectsToCSV :::', error);
    }        
    return csvStringResult;
},


})