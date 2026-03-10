import {  api,  LightningElement,  wire,  track} from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import ORDERNUM_FIELD from '@salesforce/schema/Order.OrderNumber';
import ORDERTOTAL_FIELD from '@salesforce/schema/Order.GrandTotalAmount';
import PAYMENTMETHOD_FIELD from '@salesforce/schema/Order.NATT_Payment_Instruction__c';
import ESTIMATEDTAX_FIELD from '@salesforce/schema/Order.TotalTaxAmount';
import GRANDTOTAL_FIELD from '@salesforce/schema/Order.GrandTotalAmount';

// import fetchOrderlines from '@salesforce/apex/NATT_orderDetailsController.fetchOrderlines';
import fetchShipmentItems from '@salesforce/apex/NATT_orderDetailsController.fetchShipmentItems';
import fetchInvoiceInformation from '@salesforce/apex/NATT_orderDetailsController.fetchInvoiceInformation';

// import fetchOrderItems from '@salesforce/apex/NATT_TesOrderDetailsCon.fetchOrderlines';
import fetchOrderItems from '@salesforce/apex/NATT_TesOrderDetailsCon.fetchOrderlines';

// import fetchOrderItems from '@salesforce/apex/NATT_TesOrderDetailsCon.grabOrderItems';

import fetchOrder from '@salesforce/apex/NATT_TesOrderDetailsCon.grabOrder';
// import getShipment from '@salesforce/apex/NATT_TesOrderDetailsCon.getShipment';
import getShipment from '@salesforce/apex/NATT_TesOrderDetailsConShipment.getShipment';

import { NavigationMixin } from 'lightning/navigation';

const shipmentItemsColumns = [
    { label: 'Ship Date', fieldName: 'ShipmentDate',},
    { label: 'Invoice #', fieldName: 'Invoice' },
    { label: 'Ordered ', fieldName: 'Ordered'},
    { label: 'Shipped ', fieldName: 'Quantity' },
    { label: 'Amount  ', fieldName: 'NATT_Amount__c',type: 'currency' },
    { label: 'Packing Slip', fieldName: 'PackingSlip' },
    { label: 'Tracking Info', fieldName: 'TrackingNum'},
    { label: 'Bill of Lading', fieldName: 'BillOfLading' }
  ];
  
  const Shipmentscolumns = [
   
    {label: 'Invoice #', fieldName: 'NATT_InvoiceNumber__c',type: "button", sortable: "true",
      typeAttributes: {  
        label: { fieldName: 'NATT_InvoiceNumber__c'},  
        name: 'OpenInvoice',  
        title: 'openInvoice',  
        disabled: false,  
        value: 'openInvoice',  
        iconPosition: 'left',
        variant: 'base'
      }
    },
    { label: 'Packing Slip', fieldName: 'NATT_PackingSlipNumber__c'},
    { label: 'Tracking Info', fieldName: 'TrackingNumber'},
    { label: 'Bill of Lading', fieldName: 'NATT_BillOfLading__c'},
  ];

  const FIELDS = [
    ORDERNUM_FIELD,
    ORDERTOTAL_FIELD,
    PAYMENTMETHOD_FIELD,
    ESTIMATEDTAX_FIELD,
    GRANDTOTAL_FIELD
  ];

export default class Natt_TesOrderDetailsComponent extends NavigationMixin (LightningElement) {  

  @api recordId;
  invoiceid;
  isloading = true;
  orderLines;
  invoiceLines;
  subtotal = 0.00;
  freightTotal= 0.00;
  totalTaxAmount= 0.00;
  orderTotal= 0.00;
  shippedTotal=0;
  shippedOrderTotal=0;
  rushOrderFeeTotal=0;
  packingSlipNumber;
  shipmentItemsColumns = shipmentItemsColumns;
  shipmentscolumns = Shipmentscolumns;
  shipmentCosts;
  orderItemHold;
  partNumber;
  partDescription;
  @track shipMentItems;
  isModalOpen = false;
  modalLoading = true;
  @track shipments;
  hasShipments=false;
  hasCreditCard=false;
  @track OrderItemLineTable;
  @track sortBy;
  @track sortDirection;

  @wire(getRecord, { recordId:  "$recordId", fields: [ORDERNUM_FIELD] })
  OrderNum;

  get OrderNumber() {
      return getFieldValue(this.OrderNum.data, ORDERNUM_FIELD);
  }

  @wire(getRecord, { recordId:  "$recordId", fields: [PAYMENTMETHOD_FIELD] })
  shipmentMethodValue;

  get PaymentMethod() {
      return getFieldValue(this.shipmentMethodValue.data, PAYMENTMETHOD_FIELD);
  }

  @wire(getRecord, { recordId:  "$recordId", fields: [ESTIMATEDTAX_FIELD] })
  estimatedTaxValue;
  get EstimatedTax() {
      return getFieldValue(this.estimatedTaxValue.data, ESTIMATEDTAX_FIELD);
  }

  @wire(getRecord, { recordId:  "$recordId", fields: [GRANDTOTAL_FIELD] })
  grandTotalValue;
  get GrandTotal() {
      return getFieldValue(this.grandTotalValue.data, GRANDTOTAL_FIELD);
  }


  @wire (fetchOrderItems,{recordId: '$recordId'}) 
  // @wire (fetchOrderItems,{orderId: this.recordId}) 
  wiredOrder({ data, error }) {
    console.log('Wired TES Order');    
      // if (data) {
      //     this.orderLines = data;
      //     this.orderLines.forEach((oLine)=>{
      //     if(oLine.Product2.Name.includes('FREIGHT')){
      //       console.log('freight found');
      //       this.freightTotal+=oLine.AdjustedLineAmount;
      //     }else if(oLine.Product2.Name.includes('Rush Fee')){
      //       console.log('chargeRush');
      //       this.rushOrderFeeTotal+=oLine.AdjustedLineAmount;  
      //     }
      //       this.subtotal+=oLine.AdjustedLineAmount;          
      //     });
      // } else if (error) {
      //     // handle error
      //     console.error('ERROR => ', error);
      // }else{
      //     console.log('nothing');
      // }
      // this.orderTotal = this.subtotal + this.freightTotal + this.rushOrderFeeTotal + this.totalTaxAmount;
      // this.hasShipments=false;    

      //new logic below
    if (data) {
      this.orderLines = data.orderItems;
      this.partTotal = data.partTotal;
      this.freightTotal = data.freightTotal;
      this.rushOrderTotal = data.rushOrderTotal;
      this.orderTotal = data.orderTotal;
      this.shipments = data.shipments; 
      this.shippedTotal = data.shippedTotalValue;
      console.log('Shipment Method Check: ' + this.PaymentMethod);
      if(this.PaymentMethod == 'Credit Card'){
        console.log('Credit Card Payment');
        this.hasCreditCard = true;
      }
      console.log('Tax: ' + this.EstimatedTax);
      this.totalTaxAmount = this.EstimatedTax;
      console.log('Total: ' + this.GrandTotal);
      this.orderTotal = this.GrandTotal;
      this.shippedOrderTotal=(this.shippedTotal+this.rushOrderTotal+this.freightTotal);
      // if(this.shipments && this.shipments.length>0){
      //     this.hasShipments=true;
      // }
      
      this.isloading = false;
      this.error = undefined;
    } else if (error) {
      this.error = error;
    }
  }

  @wire (getShipment,{orderId: '$recordId'}) 
    wiredShipment({ data, error }) {
      console.log('Wired Shipment');
      console.log('called with:'+this.recordId);
      if (data) {
          console.log('Data = true');
          this.shipments = data;
          if(this.shipments && this.shipments.length >0){
            console.log('hasShipments=true');
            this.hasShipments = true;
          }
        } else if (error) {
            // handle error
            console.error('ERROR => ', error);
        }else{
            console.log('nothing');
        }
        
    }

  connectedCallback() {
    this.showSpinner = false;
  }
 
  openModal(event) {
    // to open modal set isModalOpen tarck value as true
    this.modalLoading = true;
    this.isModalOpen = true;  
    var shipmentId =  event.currentTarget.id.substring(0, 18);
    fetchShipmentItems({recordId: shipmentId })
            .then(result => {
                this.partNumber = result.partNum;
                this.partDescription = result.description;
                if ( result.shipmentItems ) {            
                  let tempRecords = JSON.parse( JSON.stringify( result.shipmentItems ) );
                  tempRecords = tempRecords.map( row => {
                      return { ...row,
                                ShipmentDate: row.Shipment.NATT_DateShipped__c, 
                                Invoice: row.Shipment.NATT_InvoiceNumber__c,
                                Ordered: row.NATT_OrderProduct__r.Quantity, 
                                PackingSlip: row.Shipment.NATT_PackingSlipNumber__c,
                                TrackingNum : row.Shipment.TrackingNumber,
                                BillOfLading: row.Shipment.NATT_BillOfLading__c };
                  })
                  this.shipMentItems  = tempRecords;      
              }
              this.modalLoading = false;   
                this.error = undefined;
            })
            .catch(error => {
                this.error = error;
                this.contacts = undefined;
            });
     this.modalLoading = false;     
  }

  closeModal() {
      // to close modal set isModalOpen tarck value as false
      this.isModalOpen = false;
      this.partNumber = null;
      this.partDescription = null;
      this.shipMentItems  = null; 
  }
  
  callRowAction(event ) {
    const recId =  event.detail.row.Id;
    const actionName = event.detail.action.name;   
     if(actionName === 'OpenInvoice'){
      fetchInvoiceInformation({shipmentId: recId})
        .then(result => {
          this.invoiceid = event.detail.row.Id;          
          console.log('openInvoice invoiceId: '+this.invoiceid);
          this.invoiceLines = result.orderItems;
          this.packingSlipNumber = event.detail.row.NATT_PackingSlipNumber__c;
         
          this[NavigationMixin.GenerateUrl]({
            type: 'comm__namedPage',
            attributes: {
                name:'Invoice_Detail_Page__c'
            },
            state: {
              recId: this.invoiceid
            },
          }).then(url => {
            window.open(url);
        });
          this.error = undefined;
        })
        .catch(error => {
            console.log('Invoice FAILED: ' + error.body.message);
            this.error = error;

        })
    }
  }
  onButtonClick(event){
    console.log('button clicked');
    const recId =  event.target.value;
    console.log('recId: ' + recId);
      fetchInvoiceInformation({shipmentId: recId})
        .then(result => {
          this.invoiceid = recId;          
          console.log('openInvoice invoiceId: '+this.invoiceid);
          this.invoiceLines = result.orderItems;
          //this.packingSlipNumber = event.detail.row.NATT_PackingSlipNumber__c;
         
          this[NavigationMixin.GenerateUrl]({
            type: 'comm__namedPage',
            attributes: {
                name:'Invoice_Detail_Page__c'
            },
            state: {
              recId: this.invoiceid
            },
          }).then(url => {
            window.open(url);
        });
          this.error = undefined;
        })
        .catch(error => {
            console.log('Invoice FAILED: ' + error.body.message);
            this.error = error;

        })
    
  }

  printView(){
    this[NavigationMixin.GenerateUrl]({
      type: 'comm__namedPage',
      attributes: {
          name:'Print_Detail_Page__c'
      },
      state: {
        recId: this.recordId
      },
    }).then(url => {
      window.open(url);
  });
  }

  doSorting(event) {
    this.sortBy = event.detail.fieldName;
    this.sortDirection = event.detail.sortDirection;
    this.sortData(this.sortBy, this.sortDirection);
  }

  sortData(fieldname, direction) {
      let parseData = JSON.parse(JSON.stringify(this.shipments));
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

}