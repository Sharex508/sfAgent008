({
    //Method to sort data asc/desc based on user click
    sortData : function(component,fieldName,sortDirection){
        var data = component.get("v.knowledgeList");
        //function to return the value stored in the field
        var key = function(a) { return a[fieldName]; }
        var reverse = sortDirection == 'asc' ? 1: -1;
        data.sort(function(a,b){
            var a = key(a) ? key(a) : '';
            var b = key(b) ? key(b) : '';
            return reverse * ((a>b) - (b>a));
        });
        
        //While Sorting dont sort the first column of the datatable
        if(data.length > 0){
            var serialNo = 0;
            data.forEach(function(record) {
                serialNo = serialNo + 1;
                record.recCount = serialNo;
            });
        }
        component.set("v.knowledgeList",data);
    },
    
    //Get searched result list and assign it to datatable variable
    getArticles : function(component, event, helper){
        var acticleList = event.getParam("acticleList");
        var interfaceCheck = component.get('v.communityInterface');
        if(acticleList!== null && acticleList.length > 0){
            var reclength = "Search Results (" +acticleList.length+ ")";
            component.set("v.title", reclength);
            acticleList.forEach(function(record) {
                var recCount = component.get('v.recordCount');
                record.recCount = recCount + 1;
                component.set("v.recordCount", record.recCount);
                if(interfaceCheck){
                    record.titleLink = '/' + record.Id;
                }else{
                    record.titleLink = '/Container/s/article/' + record.Id;
                }
                record.docNumber = record.NATT_Doc_Number__c;
                record.department = record.NATT_Department__c;
                record.segment = record.NATT_Segment__c;
                record.docType = record.NATT_Document_Type__c;
                record.titleToolTip = record.Title; 
                record.lstModDate = record.LastModifiedDate;
                
            });
        }else{
            var reclength = "Search Results (0)";
            component.set("v.title", reclength);
            component.set("v.knowledgeList", null);
        }
        component.set("v.knowledgeList", acticleList);
        component.set("v.spinnerEnabled", false);
    }
})