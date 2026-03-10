import {  api,  LightningElement,  wire,  track} from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import ORDERNUM_FIELD from '@salesforce/schema/Order.OrderNumber';
import ORDERTOTAL_FIELD from '@salesforce/schema/Order.GrandTotalAmount';
// import myResource1 from '@salesforce/resourceUrl/CarrierTransicoldPartsnetLogo';
import myResource from '@salesforce/resourceUrl/TesLogoPrintInvoice4';

import fetchOrderItems from '@salesforce/apex/NATT_TesOrderDetailsCon.grabOrderItems';
import fetchOrder from '@salesforce/apex/NATT_TesOrderDetailsCon.grabOrder';
// import getShipment from '@salesforce/apex/NATT_TesOrderDetailsCon.getShipment';
import getShipment from '@salesforce/apex/NATT_TesOrderDetailsConShipment.getShipment';
import { NavigationMixin } from 'lightning/navigation';

  const FIELDS = [
    ORDERNUM_FIELD,
    ORDERTOTAL_FIELD
  ];

  const Shipmentscolumns = [
   
    {label: 'Invoice #', fieldName: 'NATT_InvoiceNumber__c', sortable: "true"
    },
    { label: 'Packing Slip', fieldName: 'NATT_PackingSlipNumber__c'},
    // { label: 'Packing Slip Number', fieldName: 'NATT_PackingSlipNumber__c' },
    // { label: 'Date Shipped', fieldName: 'NATT_DateShipped__c',  sortable: "true",
    //     type: 'date',
    //     typeAttributes:{
    //         year: "numeric",
    //         month: "2-digit",
    //         day: "2-digit",
    //         timeZone:"UTC"
    // }
    // },
    { label: 'Tracking Info', fieldName: 'TrackingNumber'},
    { label: 'Bill of Lading', fieldName: 'NATT_BillOfLading__c'},
  ];

export default class Natt_TesPrintOrderDetails extends NavigationMixin (LightningElement) {  

    recordId;
    //partsnet = myResource + '/logos/partsnet.jpg';
    tesLogo = myResource;
    shipment;    
    CurrentPageReference = null;
    subtotal=0;
    freightTotal=0;
    rushOrderFeeTotal=0;
    grandTotal=0;
    totalTaxAmount=0;
    shipmentLines;
    orderTotal;
    orderLines;
    shippingStreet;
    shippingCity;
    shippingCountry;
    shippingState;
    shippingPostalCode;

    @track shipments;
    hasShipments=false;
    shipmentscolumns = Shipmentscolumns;
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.recordId = currentPageReference.state.recId;          
        }
    }


  @wire(getRecord, { recordId:  "$recordId", fields: [ORDERNUM_FIELD] })
  OrderNum;

  get OrderNumber() {
      return getFieldValue(this.OrderNum.data, ORDERNUM_FIELD);
  }

  @wire (fetchOrderItems,{orderId: '$recordId'}) 
  wiredOrder({ data, error }) {
      console.log('called with:'+this.recordId);
      if (data) {
          console.log('data:'+JSON.stringify(data));
          this.orderLines = data;
          this.shipment = data;
          this.orderLines.forEach((oLine)=>{
            console.log('line:'+JSON.stringify(oLine));
            this.subtotal+=oLine.AdjustedLineAmount;
          });
          this.grandTotal=(this.partTotal+this.rushOrderFeeTotal+this.freightTotal+this.totalTaxAmount);
      } else if (error) {
          // handle error
          console.error('ERROR => ', error);
      }else{
          console.log('nothing');
      }
      
  }

  connectedCallback() {
    this.showSpinner = false;
    console.log('RecordId Value: ' + this.recordId);
    fetchOrder({orderId:  this.recordId })
        .then(data => {
          console.log('Retrieved Order');
          console.log('Order Total ChecK: ' + data.GrandTotalAmount);
          this.orderTotal = data.GrandTotalAmount;
          this.shippingStreet = data.shippingStreet;
          this.shippingCity = data.shippingCity;
          this.shippingCountry = data.shippingCountry;
          this.shippingState = data.shippingState;
          this.shippingPostalCode = data.shippingPostalCode;
        })
        .catch(error => {
            this.error = error;
            window.console.log(' error ', error);
            this.result = undefined;
        });    
    //this.setFirstChildAsActive();
  }

  @wire (getShipment,{orderId: '$recordId'}) 
  wiredShipment({ data, error }) {
      console.log('called with:'+this.recordId);
      if (data) {
          console.log('shipment data:'+JSON.stringify(data));
          this.shipments = data;
          if(this.shipments && this.shipments.length >0){
            this.hasShipments = true;
          }
          // this.shipments = data;
          //this.shipmentLines = this.shipment.ShipmentItems;
          let tempLines=[];
        //   this.shipments.forEach((sLine)=>{                
        //       //console.log('shipmentline:'+JSON.stringify(sLine));
        //       if(sLine.NATT_OrderProduct__r.TypeCode==='Charge' && sLine.NATT_OrderProduct__r.Type==='Delivery Charge'){    
        //           console.log('charge');
        //           if(sLine.NATT_OrderProduct__r.Product2.Name.includes('Rush Fee')){
        //               console.log('chargeRush');
        //               this.rushOrderFeeTotal+=sLine.NATT_Amount__c;                        
        //           }
        //           if(sLine.NATT_OrderProduct__r.Product2.Name.includes('Freight Charge')){
        //               console.log('chargeFreight');
        //               this.freightTotal+=sLine.NATT_Amount__c;
        //           }                    
        //       }else{    
        //           tempLines.push(sLine);        
        //           this.partTotal+=sLine.NATT_Amount__c;
        //       }                
        //   });
          this.shipmentLines=tempLines;
          this.grandTotal=(this.partTotal+this.rushOrderFeeTotal+this.freightTotal);
          //console.log('linesBefore:'+JSON.stringify(this.shipmentLines));
          /*let tempRecords=[];
          this.shipmentLines.forEach((sLine)=>{
              tempRecords.push(this.flatten(sLine));
          });
          this.shipmentLines=tempRecords;            
          console.log('lines:'+JSON.stringify(this.shipmentLines));*/
      } else if (error) {
          // handle error
          console.error('ERROR => ', error);
      }else{
          console.log('nothing');
      }
      
  }

  printDialog(){
        window.print();
    }
    
    handleClose(){         
        window.close();    
    }

    // this method validates the data and creates the csv file to download
  downloadCSVFile() {   
    let rowEnd = '\n';
    let csvString = '';
    // this set elminates the duplicates if have any duplicate keys
    let rowData = new Set();

    // getting keys from data
    this.shipmentLines.forEach(function (record) {
        Object.keys(record).forEach(function (key) {
            rowData.add(key);
        });
    });

    // Array.from() method returns an Array object from any object with a length property or an iterable object.
    rowData = Array.from(rowData);
    
    // splitting using ','
    csvString += rowData.join(',');
    csvString += rowEnd;

    // main for loop to get the data based on key value
    for(let i=0; i < this.shipmentLines.length; i++){
        let colValue = 0;

        // validating keys in data
        for(let key in rowData) {
            if(rowData.hasOwnProperty(key)) {
                // Key value 
                // Ex: Id, Name
                let rowKey = rowData[key];
                // add , after every value except the first.
                if(colValue > 0){
                    csvString += ',';
                }
                // If the column is undefined, it as blank in the CSV file.
                let value = this.shipmentLines[i][rowKey] === undefined ? '' : this.shipmentLines[i][rowKey];
                csvString += '"'+ value +'"';
                colValue++;
            }
        }
        csvString += rowEnd;
    }

    // Creating anchor element to download
    let downloadElement = document.createElement('a');

    // This  encodeURI encodes special characters, except: , / ? : @ & = + $ # (Use encodeURIComponent() to encode these characters).
    downloadElement.href = 'data:text/csv;charset=utf-8,' + encodeURI(csvString);
    downloadElement.target = '_self';
    // CSV File Name
    downloadElement.download = 'Parts Details.csv';
    // below statement is required if you are using firefox browser
    document.body.appendChild(downloadElement);
    // click() Javascript function to download CSV file
    downloadElement.click(); 
  }
}