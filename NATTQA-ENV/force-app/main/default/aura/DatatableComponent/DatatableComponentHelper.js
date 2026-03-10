({
    next: function (component, event) {
        let sObjectList = component.get("v.dataList");
        let end = component.get("v.endPage");
        let start = component.get("v.startPage");
        let pageSize = component.get("v.pageSize");
        
        let paginationlist = [];
        let counter = 0;
        
        for (let i = (end + 1); i < (end + pageSize + 1); i++) {
            if (sObjectList.length > i) {
                paginationlist.push(sObjectList[i]);
            }
            counter++;
        }
        
        start = start + counter;
        end = end + counter;
        
        component.set("v.startPage", start);
        component.set("v.endPage", end);
        component.set("v.currentPageDataList", paginationlist);
    },
    
    previous: function (component, event) {
        let sObjectList = component.get("v.dataList");
        let end = component.get("v.endPage");
        let start = component.get("v.startPage");
        let pageSize = component.get("v.pageSize");
        
        let paginationlist = [];
        let counter = 0;
        
        for (let i = start - pageSize; i < start; i++) {
            if (i > -1) {
                paginationlist.push(sObjectList[i]);
                counter++;
            } else {
                start++;
            }
        }
        
        start = start - counter;
        end = end - counter;
        
        component.set("v.startPage", start);
        component.set("v.endPage", end);
        component.set('v.currentPageDataList', paginationlist);
    },
    
    doInitializeDataTable: function (component) {
        let pageSize = component.get("v.pageSize");
        let returnedData = component.get("v.dataList");
        
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
    
    sortData: function (component, fieldName, sortDirection) {
        var data = component.get("v.dataList");
        var reverse = sortDirection !== 'asc';
        data.sort(this.sortBy(fieldName, reverse));
        component.set("v.dataList", data);
    },
    
    sortBy: function (field, reverse) {
        var key = 
            function (x) {
                return x[field]
            };
        reverse = !reverse ? 1 : -1;
        return function (a, b) {
            return a = key(a), b = key(b), reverse * ((a > b) - (b > a));
        }
    }
})