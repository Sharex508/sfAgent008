({
    doInit : function(component, event, helper) {
        
        //Field Action section
        
        if(component.get('v.relatedListConfigName') == 'CRL_Inventory_CampaignMember'){
            component.set('v.tableHeader', 'Field Action');
            
            component.set('v.columns', [
                {label: 'Service Field Action', fieldName: 'serviceFieldAction', type: 'text', sortable:true},
                {label: 'Status', fieldName: 'status', type: 'text', sortable:true},
                {label: 'Field Action Description', fieldName: 'fieldActionDescription', type: 'text', sortable:true},
                {label: 'Field Action Status', fieldName: 'fieldActionStatus', type: 'text', sortable:true}
            ]);    
        }
        
        //Warranty Coverages section 
        
        if(component.get('v.relatedListConfigName') == 'MobileWarrantyCoverage'){
            component.set('v.tableHeader', 'Warranty Coverages');
            
            component.set('v.columns', [
                {label: 'Description', fieldName: 'description', type: 'text', sortable:true},
                {label: 'Months', fieldName: 'months', type: 'number', sortable:true},
                {label: 'Usage', fieldName: 'usage', type: 'number', sortable:true},
                {label: 'Warranty End Date', fieldName: 'warrantyEndDate', type: 'date', typeAttributes:{month: "2-digit",day: "2-digit",year: "numeric"}, sortable:true},
                {label: 'Deductibles', fieldName: 'deductibles', type: 'currency', sortable:true}
            ]);    
        }
        
        //Upcoming/Completed Schedules section
        
        if(component.get('v.relatedListConfigName') == 'CRL_UpcomingSchedules'){
            component.set('v.tableHeader', 'Upcoming/Completed Schedules');
            
            component.set('v.columns', [
                {label: 'Contract Maintenance', fieldName: 'contractMaintenance', type: 'text', sortable:true},
                {label: 'Claim', fieldName: 'claim', type: 'text', sortable:true},
                {label: 'Inventory', fieldName: 'inventoryName', type: 'text', sortable:true},
                {label: 'status', fieldName: 'status', type: 'text', sortable:true}
            ]);    
        }
        
        //Major Components section
        
        if(component.get('v.relatedListConfigName') == 'CRL_Inventory_MajorComponents'){
            component.set('v.tableHeader', 'Major Components');
            
            component.set('v.columns', [
                {label: 'Part_Description', fieldName: 'partDescription', type: 'text', sortable:true},
                {label: 'Model/Part Information', fieldName: 'modelPartInformation', type: 'text', sortable:true},
                {label: 'Serial Number', fieldName: 'serialNumber', type: 'text', sortable:true}
            ]);  
        }
        
        //Claim section
        
        if(component.get('v.relatedListConfigName') == 'ClaimMobile'){
            component.set('v.tableHeader', 'Claim');
            
            component.set('v.columns', [
                {label: 'Claim Number', fieldName: 'claimNumber', type: 'text', sortable:true},
                {label: 'Date Of Failure', fieldName: 'dateOfFailure', type: 'date', typeAttributes:{month: "2-digit",day: "2-digit",year: "numeric"}, sortable:true},
                {label: 'Casual Part Description', fieldName: 'casualPartDescription', type: 'text', sortable:true},
                {label: 'Claim Type', fieldName: 'claimType', type: 'text', sortable:true}
            ]);    
        }
    }
})