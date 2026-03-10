({
    init: function (component, event, helper) {
        console.log('init start');
        var actions = [
            {label: $A.get("$Label.c.NATT_Addresses_Edit"), name: 'edit'},
            {label: $A.get("$Label.c.NATT_Addresses_Delete"), name: 'delete'}
        ];

        component.set('v.columnsEdit', [
            {label: '#', fieldName: 'RowNumber', type: 'text',initialWidth: 40, sortable: true, cellAttributes: {alignment: 'center'} },
            {label: $A.get("$Label.c.NATT_Addresses_Name"), fieldName: 'Name', type: 'text', sortable: true},
            {label: $A.get("$Label.c.NATT_Addresses_Street"), fieldName: 'Street', type: 'text', sortable: true},
            {label: $A.get("$Label.c.NATT_Addresses_City"), fieldName: 'City', type: 'text', sortable: true},
            {label: $A.get("$Label.c.NATT_Addresses_State"), fieldName: 'State', type: 'text', sortable: true},
            {label: $A.get("$Label.c.NATT_Addresses_Zip_Code"), fieldName: 'PostalCode', type: 'text', sortable: true},
            {label: $A.get("$Label.c.NATT_Addresses_Country"), fieldName: 'Country', type: 'text', sortable: true},
            {type: 'action', typeAttributes: { rowActions: actions }},
        ])
        component.set('v.columnsNATT', [
            {label: $A.get("$Label.c.NATT_Addresses_Name"), fieldName: 'Name', type: 'text', sortable: true, editable: false},
            {label: $A.get("$Label.c.NATT_Addresses_Street"), fieldName: 'Street', type: 'text', sortable: true, editable: false},
            {label: $A.get("$Label.c.NATT_Addresses_City"), fieldName: 'City', type: 'text', sortable: true, editable: false},
            {label: $A.get("$Label.c.NATT_Addresses_State"), fieldName: 'State', type: 'text', sortable: true, editable: false},
            {label: $A.get("$Label.c.NATT_Addresses_Zip_Code"), fieldName: 'PostalCode', type: 'text', sortable: true, editable: false},
            {label: $A.get("$Label.c.NATT_Addresses_Country"), fieldName: 'Country', type: 'text', sortable: true, editable: false}
        ])
        helper.fetchData(component);
        helper.fetchDataJDE(component);
        helper.fetchAccountDetails(component);
        helper.closeModal(component);
       

    },

    
    handleRowAction : function(component, event, helper) {
    var action = event.getParam('action');
    var row = event.getParam('row');
    var recId = row.Id;  

    if (action.name === 'edit') {
        // Store selected record and open modal
        component.set("v.selectedRecord", row);
        component.set("v.isModalOpen", true);
    } else if (action.name === 'delete') {
        // Optional: handle delete logic
        helper.deleteRecord(component, event);
                helper.fetchData(component);
                helper.fetchDataJDE(component);
                helper.fetchAccountDetails(component);
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

    onSave: function (component, event, helper){
        var updatedRecords = event.getParam('draftValues');
        var action = component.get( "c.updateAddresses" );  
        action.setParams({  
            'updatedAccountList' : updatedRecords  
        });  
        action.setCallback( this, function( response ) {  
            var state = response.getState();   
            if ( state === "SUCCESS" ) {  
                  if ( response.getReturnValue() === true ) {  
                    component.set("v.draftValues", null);
                    $A.get('e.force:refreshView').fire();
                } else {    
                    component.find('notifLib').showToast({
                        "title" : "Error",
                        "message": "Something went wrong. Contact your system administrator."
                    });  
                }      
            } else {      
                component.find('notifLib').showToast({
                    "title" : "Error",
                    "message": "Something went wrong. Contact your system administrator."
                }); 
            }    
        });  
        $A.enqueueAction( action ); 
        helper.fetchData(component);
    },

    handleSave : function(component, event, helper) {
        var nameValue = component.find("nameField").get("v.value");
        var streetValue = component.find("streetField").get("v.value");
        var cityValue = component.find("cityField").get("v.value");
        var stateValue = component.find("stateField").get("v.value");
        var zipValue = component.find("zipField").get("v.value");
        if(nameValue == null){
            component.find('notifLib').showToast({
                "title": "ERROR!",
                "message": "Please enter a Name."
            });
            return;
        }else if(streetValue == null){
            component.find('notifLib').showToast({
                "title": "ERROR!",
                "message": "Please enter a Street.",
                "type": "error"
            });
            return;
        }else if(cityValue == null){
            component.find('notifLib').showToast({
                "title": "ERROR!",
                "message": "Please enter a City."
            });
            return;
        }else if(stateValue == null){
            component.find('notifLib').showToast({
                "title": "ERROR!",
                "message": "Please enter a State.",
                "type": 'error'
            });
            return;
        }else if(zipValue == null){
            component.find('notifLib').showToast({
                "title": "ERROR!",
                "message": "Please enter a Zip."
            });
            return;
        }
        //Added By Rajasekharreddy Kotella CCRN-1171
        else if(nameValue && nameValue.length > 40 ){
            component.find('notifLib').showToast({
                "title": "ERROR!",
                "message": "Name should not be greater than 40 characters."
            });
            return;
        }
        helper.submitAddress(component);
    },

    handleError: function(component, event) {
        // helper.toastMsg( 'error', 'Something went wrong. Contact your system administrator.' );
        console.log('E R R O R ');
        var errors = event.getParams();
        console.log("response", JSON.stringify(errors));
    },

    openModel : function(component, event, helper) {
        component.set("v.isModalOpen", true);
    },

    closeModel : function(component, event, helper) {
        component.set("v.isModalOpen", false);
        component.set("v.selectedRecord", null);
    },

    handleAddressCreated : function(component, event, helper) {
        component.set("v.isModalOpen", false);
        // refresh data table
        helper.fetchDropShipAddresses(component);
    },
    
    handleAddressUpdated : function(component, event, helper) {
        component.set("v.isModalOpen", false);
        helper.fetchDropShipAddresses(component);
    },

     closeEdit: function(component, event, helper) {
        // Set isModalOpen attribute to false  
        helper.fetchData(component);
        helper.fetchDataJDE(component);
        helper.fetchAccountDetails(component);
        component.set("v.isRecordEditOpen", true);
    },

     handleSuccess : function(component, event, helper) {
        component.find('notifLib').showToast({
            "variant": "success",
            "title": "Address Updated",
            "message": "Address was updated successfully!"
        });
        helper.fetchData(component);
        helper.fetchDataJDE(component);
        helper.fetchAccountDetails(component);
        component.set("v.isRecordEditOpen", true);
    },
  

    handleSubmit : function(component, event, helper) {
        // event.preventDefault();       // stop the form from submitting
        
        const fields = event.getParam('fields');
        console.log('after fields');
     
        component.find('myRecordForm').submit(fields);

      
    },
    handleError: function(component, event) {
        
        },
    
    //Added By Rajasekharreddy Kotella CCRN-1171
    handleNameChange: function(component, event, helper) {
        var nameField = component.find("nameField").get("v.value");
        console.log('Length--');
        console.log('Length--'+nameField.length);
        if (nameField && nameField.length > 40) {
            component.set("v.nameFieldError", "Name should not be greater than 40 characters.");
        } else {
            component.set("v.nameFieldError", "");
        }
    },
    
    handleAddressUpdated : function(component, event, helper) {
    component.set("v.isModalOpen", false);
    component.set("v.selectedRecord", null);


    helper.fetchDropShipAddresses(component);
},


})