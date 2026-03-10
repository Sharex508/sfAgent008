import { LightningElement,api, wire } from 'lwc';
import getOrderList from '@salesforce/apex/NATT_CtbrPreQuoteCon.getOrders'; 
import getOutOfStock from '@salesforce/apex/NATT_CtbrPreQuoteCon.getOutOfStock';
import createOrderFromOutOfStock from '@salesforce/apex/NATT_CtbrPreQuoteCon.createOrderFromOutOfStock';
import approveOrder from '@salesforce/apex/NATT_CtbrPreQuoteCon.approveOrder';
import { refreshApex } from '@salesforce/apex';

const outOfStockColumns = [
    { label: 'Número de encomenda', fieldName: 'NATT_OrderNumberSFDC__c' },
    { label: 'Número da peça', fieldName: 'Part_Number__c' },
    { label: 'Quantidade', fieldName: 'Quantity' },
    { label: 'Quantidade disponível', fieldName: 'CTBR_QuantityAvailable__c'}
];
const awaitingApprovalColumns = [
    { label: 'Part Number', fieldName: 'Part_Number__c' },    
    { label: 'Total Payable', fieldName: 'CTBR_TotalPayable__c'},
    { label: 'Quantity', fieldName: 'Quantity'},
    { label: 'Total ICMS', fieldName: 'CTBR_TotalICMS__c'},
    { label: 'Total ICMS ST', fieldName: 'CTBR_TotalICMSST__c'},
    { label: 'Total IPI', fieldName: 'CTBR_TotalIPI__c'},
    { label: 'Taxation', fieldName: 'CTBR_Taxation__c'},
    { label: 'Subtotal ICMS', fieldName: 'CTBR_SubtotalICMS__c'}
];

export default class Natt_ctbrPreQuote extends LightningElement {
    awaitingApprovalList=[];
    outOfStockList=[];
    outOfStockColumns = outOfStockColumns;
    awaitingApprovalColumns = awaitingApprovalColumns;
    @api effectiveAccountId;
    showSpinner=false;
    error;
    wiredWaitingCustomerApproval;
    wiredOutOfStock;

    @wire (getOrderList,{orderStatus : 'Awaiting Customer Approval'})
    wiredCustomerApproval(value){
        this.wiredWaitingCustomerApproval = value;
        const {data,error} = value;
        if(data){
            console.log('awaitingCustomerApproval data:'+JSON.stringify(data));
            this.awaitingApprovalList=data;            

        }else if(error){
            this.error=JSON.stringify(error);                 
            console.log('error in getOrderList: '+JSON.stringify(error));        
        }
    }

    @wire (getOutOfStock)
    wiredOOS(value){
        this.wiredOutOfStock = value;
        const {data,error} = value;
        if(data){
            console.log('out of stock data:'+JSON.stringify(data));
            this.outOfStockList=data;
        }else if(error){
            this.error=JSON.stringify(error);                 
            console.log('error in getOrderList2: '+JSON.stringify(error));        
        }
    }
    
    handleApproveOrder(event){
        this.error=null;
        this.showSpinner = true;
        let orderId = event.target.dataset.id;
        console.log('orderId: '+orderId);
        approveOrder(
            {orderId : orderId}
        )
        .then(()=>{
            refreshApex(this.wiredWaitingCustomerApproval);
        })
        .catch((e) => {
            console.log(e);
            this.error = e;
        })
        .finally(() => {
            this.showSpinner = false;
        });
    }

    handleCreateOutOfStockOrder(){
        this.error=null;
        this.showSpinner = true;
        let dt = this.template.querySelector('[data-id="outOfStock"]');        
        let selectedRows = dt.getSelectedRows();
        let oiList = [];
        selectedRows.forEach(function(orderItem){            
            oiList.push(orderItem.Id);
        });
        createOrderFromOutOfStock(
            {oiIdList:oiList}
            ).then((orderObj)=>{
                console.log('orderCreated:'+JSON.stringify(orderObj));
                refreshApex(this.wiredOutOfStock);
            })
            .catch((e) => {
                console.log(e);
                this.error = e;
              })
              .finally(() => {
                this.showSpinner = false;
              });
        
    }

    /*this.awaitingApprovalList=[];
            this.awaitingApprovalList = data.map((row) => {
                row = { ...row }; // copy row object
                const items = row.OrderItems; // Save items
                delete row.OrderItems; // remove from row
                row._children = items.map((item) => flattenObject(item)); // flatten item
                return row;
              });
            console.log('awaitingApprovalList:'+JSON.stringify(this.awaitingApprovalList));    
            let strData = JSON.parse( JSON.stringify( data ) );            
            strData.map((row, index) => {
                if (row['OrderItems']) {
                    row._children = row['OrderItems']; //define rows with children 
                    delete row.OrderItems;
                    
                    let iconKey = "iconName";
                    row[iconKey] = 'standard:order';
                }     
            });
            console.log('strData:'+JSON.stringify(strData));
            this.awaitingApprovalList = strData; 
            
        function flattenObject(object, result = {}, path = []) {
    for (const [key, value] of Object.entries(object)) {
      if (typeof value === "object") {
        flattenObject(value, result, [...path, key]);
      } else {
        result[`${path.join(".")}${path.length ? "." : ""}${key}`] = value;
      }
    }
    return result;
  }*/
}