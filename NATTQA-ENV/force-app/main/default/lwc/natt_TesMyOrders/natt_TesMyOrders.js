import {  api,  LightningElement,  wire,  track} from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import UserId from '@salesforce/user/Id';
import grabOrders from '@salesforce/apex/NATT_TesOrderDetailsCon.grabMyOrders';
import { NavigationMixin } from 'lightning/navigation';
import CommunityId from "@salesforce/community/Id";

const columns = [
    // { label: 'Order Number', fieldName: 'OrderNumber' },
    {label: 'Order Number', fieldName: 'OrderNumber',type: "button", sortable: "true",
      typeAttributes: {  
        label: { fieldName: 'OrderNumber'},  
        name: 'OpenOrder',  
        title: 'Click to View Order',  
        disabled: false,  
        value: 'openOrder',  
        iconPosition: 'left',
        variant: 'base'
      },
      cellAttributes: {
        class: 'button',
        alignment: 'right',
    }
    },
    { label: 'Order Date', fieldName: 'EffectiveDate', type: 'date', sortable: "true" },
    { label: 'Number of Products', fieldName: 'NATT_Number_of_Order_Products__c' },
    { label: 'Order Total', fieldName: 'GrandTotalAmount', type: 'currency'},
    // { label: 'NATT Status', fieldName: 'NATT_Order_Status__c'},.slds-text-title_bold

];

export default class Natt_TesMyOrders extends NavigationMixin (LightningElement) { 
    data = [];
    columns = columns;
    @track myOrderList;
    @track myOrderListHold;
    @track myOrderListPerPage;
    @track page = 1; 
    @track items = []; 
    @track data = []; 
    @track startingRecord = 1;
    @track endingRecord = 0; 
    @track pageSize = 25; 
    @track totalRecountCount = 0;
    @track totalPage = 0;
    @track disableFirstButton = true;
    @track disablePreviousButton = true;
    @track disableNextButton = false;
    @track disableLastButton = false;
    @track disableDownloadButton = false;
    @track existingOrders = false;

    recordPageUrl;
    // eslint-disable-next-line @lwc/lwc/no-async-await
    async connectedCallback() {
        const data = await fetchDataHelper({ amountOfRecords: 100 });
        this.data = data;
    }

    connectedCallback(){
        this.grabMyOrders();
    }
    
    grabMyOrders(){
        grabOrders({UserId:UserId, CommunityId : CommunityId})
        .then(result => {
            this.myOrderList = result;
            this.items = result;

            //check to see if user has placed any orders. If so, mark existingOrders as true to display
            if(this.myOrderList.length == 0 || this.myOrderList.length == null){
                this.existingOrders = false;
            } else {
                this.existingOrders = true;
            }
            this.totalRecountCount = this.myOrderList.length; 
            
            this.totalPage = Math.ceil(this.totalRecountCount / this.pageSize);
            if(this.totalPage == 0){
                this.totalPage = 1;
            }
            this.myOrderList = this.items.slice(0,this.pageSize); 
            this.endingRecord = this.pageSize;
            this.disableOrEnableButtons();

        })
        .catch(error => {
            console.log('Orders FAILED load: ' + error.body.message);
            this.error = error;
        })
    }

    handleSort(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData(this.sortBy, this.sortDirection);
      }

      sortData(fieldname, direction) {
        let parseData = JSON.parse(JSON.stringify(this.myOrderList));
        // Return the value stored in the field
        let keyValue = (a) => {
            return a[fieldname];
        };
        // cheking reverse direction
        let isReverse = direction === 'asc' ? 1: -1;
        // sorting data
        parseData.sort((x, y) => {
            x = keyValue(x) ? keyValue(x) : ''; // handling null values
            y = keyValue(y) ? keyValue(y) : '';
            // sorting values based on direction
            return isReverse * ((x > y) - (y > x));
        });
        this.shipments = parseData;
    }    

    callRowAction(event ) {
        const recId =  event.target.value;
        // console.log('RecId: ' + recId);
        // const recId =  event.detail.row.Id;
        var orderId = recId;
        // console.log('Order Id: ' + recId);
        // const actionName = event.detail.action.name;   
        //  if(actionName === 'OpenOrder'){
            console.log('Open Order ' + recId);
            // this[NavigationMixin.Navigate]({
            //     type: 'comm__namedPage',
            //     attributes: {
            //         name:'Order_Detail__c',
            //     },
            //     state: {
            //         recId: recId
            //       },
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: 'order/'+orderId
                }
            // this[NavigationMixin.Navigate]({
            //     type: 'comm__namedPage',
            //     attributes: {
            //         pageName: 'Order_Detail__c'
            //     }
               
           
            //     // this.recordPageUrl = generatedUrl;
            })
            .catch(error => {
                console.log('BUTTON FAILURE: ' + error.body.message);
                this.error = error;
            });
        // }
    }

    //check to see if navigation buttons should be disabled or not
    disableOrEnableButtons(){
        //disables or enables next & last buttons
        if(this.page == this.totalPage || this.totalPage == 0){
            this.disableNextButton = true;
            this.disableLastButton = true;
        }else{
            this.disableNextButton = false;
            this.disableLastButton = false;
        }

        //disables or enables previous & first buttons
        if(this.page == 1){
            this.disablePreviousButton = true;
            this.disableFirstButton = true;
        } else{
            this.disablePreviousButton = false;
            this.disableFirstButton = false;
        }
    }

    //clicking on first button returns table to first page
    handleFirst() {
        this.page = 1; //set to first page
        this.displayRecordPerPage(this.page);
        this.disableOrEnableButtons();
    }

    //clicking on previous button this method will be called
    previousHandler() {
        if (this.page > 1) {
            this.page = this.page - 1; //decrease page by 1
            this.displayRecordPerPage(this.page);
        }
        this.disableOrEnableButtons();
    }

    //clicking on next button this method will be called
    nextHandler() {
        if((this.page<this.totalPage) && this.page !== this.totalPage){
            this.page = this.page + 1; //increase page by 1
            this.displayRecordPerPage(this.page);            
        }  
        this.disableOrEnableButtons();       
    }

    //clicking on last button sets table to final page
    handleLast() {
        this.page = this.totalPage; //set to last page
        this.displayRecordPerPage(this.page);            
        this.disableOrEnableButtons();
    }
    //this method displays records page by page
    displayRecordPerPage(page){

        this.startingRecord = ((page -1) * this.pageSize) ;
        this.endingRecord = (this.pageSize * page);

        this.endingRecord = (this.endingRecord > this.totalRecountCount) 
                            ? this.totalRecountCount : this.endingRecord; 

        this.myOrderList = this.items.slice(this.startingRecord, this.endingRecord);

        this.startingRecord = this.startingRecord + 1;
    }    


}