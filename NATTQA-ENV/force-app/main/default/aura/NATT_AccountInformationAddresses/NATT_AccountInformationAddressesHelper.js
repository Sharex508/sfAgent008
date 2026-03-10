({
    fetchData: function (component, fetchData, numberOfRecords) {
        // var userId = $A.get("$SObjectType.CurrentUser.Id");
        var effAccountId = component.get("v.effectiveAccountId");
        console.log('effectiveAccountId: ' + effAccountId);
        var action = component.get("c.grabAddresses");
        action.setParams({
            "effAccountId" : effAccountId
        });
        action.setCallback(this, function(response){
            var state = response.getState();
            if (state === "SUCCESS") {
                var records = response.getReturnValue();
                //component.set("v.data", response.getReturnValue());
                // records.forEach(function(record){
                // })
                records.forEach(function(record, index) {
                record.RowNumber = index + 1;
            });

            component.set("v.data", records);
            }
        });
        $A.enqueueAction(action);
    },

    fetchDataJDE: function (component, fetchData, numberOfRecords) {
        // var userId = $A.get("$SObjectType.CurrentUser.Id");
        var effAccountId = component.get("v.effectiveAccountId");
        var action = component.get("c.grabJdeAddresses");
        console.log('Fetch Natt');
        action.setParams({
            "effAccountId" : effAccountId
        });
        action.setCallback(this, function(response){
            console.log('set callback Natt');

            var state = response.getState();
            if (state === "SUCCESS") {
                console.log('success');

                var records = response.getReturnValue();
                component.set("v.dataJDE", response.getReturnValue());
            }
        });
        $A.enqueueAction(action);
    },

    fetchAccountDetails: function (component, fetchData, numberOfRecords) {
        console.log('Fetch Account Details');
        // var userId = $A.get("$SObjectType.CurrentUser.Id");
        var effAccountId = component.get("v.effectiveAccountId");
        var action = component.get("c.grabAccountDetails");
        action.setParams({
            "acctId" : effAccountId
        });
        action.setCallback(this, function(response){
            var state = response.getState();
            if (state === "SUCCESS") {
                var records = response.getReturnValue();
                console.log('successful grab: ' + records);

                // console.log('related accountId value: ' + records[Id]);

                component.set("v.relatedAccount", records);
                // records.forEach(function(record){
                // })
            }
        });
        $A.enqueueAction(action);
    },


    fetchTopData: function (component) {
        var action = component.get("c.getTopOrderedItems");
        action.setParams({
        });
        action.setCallback(this, function(response){
            var state = response.getState();
            if (state === "SUCCESS") {
                var records = response.getReturnValue();
                console.log('records value: ' + records);
                component.set("v.topBackorderData", response.getReturnValue());
            }
        });
        $A.enqueueAction(action);
    },

    // viewDetails : function(event, action, component, row) {
    //     var rows = component.get('v.data');
    //     var rowIndex = rows.indexOf(row);
    //     var recId = component.get("v.recordId");
    //     var navEvt = $A.get("e.force:navigateToSObject");
    //     navEvt.setParams({
    //       "recordId": row.Id,
    //       "slideDevName": "related"
    //     });
    //     navEvt.fire();
    // },

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
        var data = component.get("v.data");
        var reverse = sortDirection !== 'asc';
        data.sort(this.sortBy(fieldName, reverse))
        component.set("v.data", data);
    },
    sortBy: function (field, reverse) {
        var key = function(x) {return x[field]};
        reverse = !reverse ? 1 : -1;
        return function (a, b) {
            return a = key(a), b = key(b), reverse * ((a > b) - (b > a));
        }
    },


    submitAddress: function (component, event) {
        console.log('helper submit address');
        var completedForm = component.find("recordEditForm");
        completedForm.submit();
        console.log('helper AFTER submit');
        // var userId = $A.get("$SObjectType.CurrentUser.Id");
        var userId = component.get("v.effectiveAccountId");
        var action = component.get("c.grabAddresses");
        action.setParams({
            "userId" : userId
        });
        // action.setCallback(this, function(response){
        //     var state = response.getState();
        //     console.log('State Value: ' + state);
        //     if (state === "SUCCESS") {
        //         var records = response.getReturnValue();
        //         console.log('records: ' + JSON.stringify(records));
        //         component.set("v.data", response.getReturnValue());
        //         console.log('success end');
        //     }
        // });
        // $A.enqueueAction(action);
        console.log('end of submitAddress');
    },

    closeModal: function (component, event){
        console.log('close modal action');
        component.set("v.isModalOpen", false);  
    },
    
    deleteRecord : function(component, event) {
        console.log('delete record start');
        component.set("v.isLoading", true);
        var thisHelper = this;
        var action = event.getParam('action');
        var conPointAddress = event.getParam('row');        
        var action = component.get("c.deleteAddress");
        action.setParams({
            "conPointAddress": conPointAddress
        });
        action.setCallback(this, function(response) {      
            console.log('Delete section');      
            if (response.getState() === "SUCCESS" ) {
                var rows = component.get('v.results');
                component.set('v.results', rows);
                component.find('notifLib').showToast({
                    "title": "Success!",
                    "message": "The selected drop ship address was deleted successfully.",
                    "type": "success"
                });
            }
            else{
                console.log('DELETE FAILED: ' + JSON.stringify(response.getError()));
                component.find('notifLib').showToast({
                    "title": "Error",
                    "message": JSON.stringify(response.getError()),
                    "type": "error"
                });                
            }
        });
        $A.enqueueAction(action);
    },
    fetchDropShipAddresses : function(component) {
    var action = component.get("c.grabAddresses"); 
    action.setParams({
        effAccountId: component.get("v.effectiveAccountId")
    });

    action.setCallback(this, function(response) {
        var state = response.getState();
        if (state === "SUCCESS") {
            var records = response.getReturnValue();

            
            records.forEach(function(record, index) {
                record.RowNumber = index + 1;
            });

            component.set("v.data", records);
        } else {
            console.error('Error fetching Drop Ship Addresses');
        }
    });

    $A.enqueueAction(action);
},

    
    
})