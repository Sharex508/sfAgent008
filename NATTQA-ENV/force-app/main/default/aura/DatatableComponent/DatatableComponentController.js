({
    doInit : function(component, event, helper) {
        let returnedData = component.get("v.dataList");
        let pageSize = component.get("v.pageSize");
        
        component.set("v.totalRecords", component.get("v.dataList").length);
        component.set("v.startPage", 0);
        component.set("v.endPage", parseInt(pageSize) - 1);
        
        let paginationList = [];
        
        for (let i = 0; i < pageSize; i++) {
            if (returnedData.length > i) {
                paginationList.push(returnedData[i]);
            }
        }
        
        component.set('v.currentPageDataList', paginationList);
    },
    
    next: function (component, event, helper) {
        component.set("v.isPaginationButtonClicked", true);
        let currentPageNumber = component.get("v.currentPageNumber");
        component.set("v.currentPageNumber", currentPageNumber + 1);
        helper.next(component, event);
    },
    
    previous: function (component, event, helper) {
        component.set("v.isPaginationButtonClicked", true);
        let currentPageNumber = component.get("v.currentPageNumber");
        component.set("v.currentPageNumber", currentPageNumber - 1);
        helper.previous(component, event);
    },
    
    dataListChangeHandler: function (component, event, helper) {
        helper.doInitializeDataTable(component);
    },
    
    updateColumnSorting: function (component, event, helper) {
        var fieldName = event.getParam('fieldName');
        var sortDirection = event.getParam('sortDirection');
        component.set("v.sortedBy", fieldName);
        component.set("v.sortedDirection", sortDirection);
        helper.sortData(component, fieldName, sortDirection);
    }
})