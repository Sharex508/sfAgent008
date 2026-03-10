import {  api,  LightningElement,  wire,  track} from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { CurrentPageReference } from 'lightning/navigation';

import ORDERNUM_FIELD from '@salesforce/schema/Order.OrderNumber';
import SHIPMETHOD_FIELD from '@salesforce/schema/Order.NATT_Shipment_Method__c';
import fetchOrderlines from '@salesforce/apex/NATT_orderDetailsController.fetchOrderlines';
import fetchShipmentItems from '@salesforce/apex/NATT_orderDetailsController.fetchShipmentItems';
import fetchInvoiceInformation from '@salesforce/apex/NATT_orderDetailsController.fetchInvoiceInformation'
import { NavigationMixin } from 'lightning/navigation';
import communityId from '@salesforce/community/Id';
import getWebstore from '@salesforce/apex/NATT_BackorderReportHelper.getWebstore';
import myResource from '@salesforce/resourceUrl/CarrierLogoInvoice2';


/**Custom Label Imports */
import AmountLabel from '@salesforce/label/c.NATT_Order_Detail_Amount';
import AvailableOnLabel from '@salesforce/label/c.NATT_Order_Detail_Available_On';
import BackorderedLabel from '@salesforce/label/c.NATT_Order_Detail_Backordered';
import BillOfLadingLabel from '@salesforce/label/c.NATT_Order_Detail_Bill_of_Lading';
import CloseLabel from '@salesforce/label/c.NATT_Order_Detail_Close';
import ContactEmailLabel from '@salesforce/label/c.NATT_Order_Detail_Contact_Email';
import ContactNameLabel from '@salesforce/label/c.NATT_Order_Detail_Contact_Name';
import ContactPhoneLabel from '@salesforce/label/c.NATT_Order_Detail_Contact_Phone';
import CustomerLabel from '@salesforce/label/c.NATT_Order_Detail_Customer';
import CustomerInformationLabel from '@salesforce/label/c.NATT_Order_Detail_Customer_Information';
import CustomerNumberLabel from '@salesforce/label/c.NATT_Order_Detail_Customer_Number';
import DateShippedLabel from '@salesforce/label/c.NATT_Order_Detail_Date_Shipped';
import DescriptionLabel from '@salesforce/label/c.NATT_Order_Detail_Description';
import EstimatedRushOrderFeeLabel from '@salesforce/label/c.NATT_Order_Detail_Estimated_Rush_Order_Fee';
import FreightLabel from '@salesforce/label/c.NATT_Order_Detail_Freight';
import FreightAccountNumberLabel from '@salesforce/label/c.NATT_Order_Detail_Freight_Account_Number';
import InvoiceLabel from '@salesforce/label/c.NATT_Order_Detail_Invoice';
import InvoiceInformationLabel from '@salesforce/label/c.NATT_Order_Detail_Invoice_Information';
import ItemShipmentDetailsLabel from '@salesforce/label/c.NATT_Order_Detail_Item_Shipment_Details';
import JDESalesNumberLabel from '@salesforce/label/c.NATT_Order_Detail_JDE_Sales_Order';
import LineLabel from '@salesforce/label/c.NATT_Order_Detail_Line';
import OrderLabel from '@salesforce/label/c.NATT_Order_Detail_Order';
import OrderedLabel from '@salesforce/label/c.NATT_Order_Detail_Ordered';
import OrderedDateLabel from '@salesforce/label/c.NATT_Order_Detail_Ordered_Date';
import OrderAmountLabel from '@salesforce/label/c.NATT_Order_Detail_Order_Amount';
import OrderInformationLabel from '@salesforce/label/c.NATT_Order_Detail_Order_Information';
import OrderLinesLabel from '@salesforce/label/c.NATT_Order_Detail_Order_Lines';
import OrderTypeLabel from '@salesforce/label/c.NATT_Order_Detail_Order_Type';
import PackingSlipLabel from '@salesforce/label/c.NATT_Order_Detail_Packing_Slip';
import PackingSlipNumberLabel from '@salesforce/label/c.NATT_Order_Detail_Packing_Slip_Number';
import PartLabel from '@salesforce/label/c.NATT_Order_Detail_Part';
import PartTotalLabel from '@salesforce/label/c.NATT_Order_Detail_Part_Total';
import PNLabel from '@salesforce/label/c.NATT_Order_Detail_PN';
import POLabel from '@salesforce/label/c.NATT_Order_Detail_PO';
import ShipmentsLabel from '@salesforce/label/c.NATT_Order_Detail_Shipments';
import ShipmentMethodLabel from '@salesforce/label/c.NATT_Order_Detail_Shipment_Method';
import ShipmentTermsLabel from '@salesforce/label/c.NATT_Order_Detail_Shipment_Terms';
import ShippedLabel from '@salesforce/label/c.NATT_Order_Detail_Shipped';
import ShippedAmountLabel from '@salesforce/label/c.NATT_Order_Detail_Shipped_Amount';
import ShippingAddressLabel from '@salesforce/label/c.NATT_Order_Detail_Shipping_Address';
import ShippingCompanyLabel from '@salesforce/label/c.NATT_Order_Detail_Shipping_Company';
import ShipDateLabel from '@salesforce/label/c.NATT_Order_Detail_Ship_Date';
import StatusLabel from '@salesforce/label/c.NATT_Order_Detail_Status';
import TotalLabel from '@salesforce/label/c.NATT_Order_Detail_Total';
import TrackingInfoLabel from '@salesforce/label/c.NATT_Order_Detail_Tracking_Info';
import unitPriceLabel from '@salesforce/label/c.NATT_Order_Detail_Unit_Price';
import ReasonForShippingMethodLabel from '@salesforce/label/c.NATT_Checkout_Reason_for_Shipment_Method';
import SerialNumberLabel from '@salesforce/label/c.NATT_Checkout_Serial_Number';
import FlightItineraryLabel from '@salesforce/label/c.NATT_Checkout_Flight_Itinerary';
import FreightCompanyInformationLabel from '@salesforce/label/c.NATT_Checkout_Freight_Company_Information';
import AdditionalInformationLabel from '@salesforce/label/c.NATT_Checkout_Additional_Information';

const shipmentItemsColumns = [
  //{ label: ShipDateLabel, fieldName: 'ShipmentDate',},
  { label: InvoiceLabel, fieldName: 'Invoice' },
  { label: OrderedLabel, fieldName: 'Ordered'},
  { label: ShippedLabel+' ', fieldName: 'Quantity' },
  { label: AmountLabel+'  ', fieldName: 'NATT_Amount__c',type: 'currency' },
  { label: PackingSlipLabel, fieldName: 'PackingSlip' },
  { label: TrackingInfoLabel, fieldName: 'TrackingNum'},
  { label: ShippingCompanyLabel, fieldName: 'ShippingCompanyName'},
  { label: BillOfLadingLabel, fieldName: 'BillOfLading' }
];

const Shipmentscolumns = [
  {label: InvoiceLabel, fieldName: 'NATT_InvoiceNumber__c',type: "button", sortable: "true",
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
  { label: PackingSlipNumberLabel, fieldName: 'NATT_PackingSlipNumber__c' },
  { label: DateShippedLabel, fieldName: 'NATT_DateShipped__c',  sortable: "true",
      type: 'date',
      typeAttributes:{
          year: "numeric",
          month: "2-digit",
          day: "2-digit",
          timeZone:"UTC"
  }
  },
  { label: TrackingInfoLabel, fieldName: 'TrackingNumber'},
  { label: ShippingCompanyLabel, fieldName: 'NATT_ShippingCompanyName__c'},
  { label: BillOfLadingLabel, fieldName: 'NATT_BillOfLading__c'},
];

export default class Natt_CtbrPrintOrderDetails  extends NavigationMixin (LightningElement) {  

    /**
     * Custom Label creation
     */
    label = {
      AdditionalInformationLabel,
      AvailableOnLabel,
      AmountLabel,
      CloseLabel,
      ContactEmailLabel,
      ContactNameLabel,
      ContactPhoneLabel,
      CustomerLabel,
      CustomerInformationLabel,
      OrderInformationLabel,
      CustomerNumberLabel,
      POLabel,    
      BackorderedLabel,
      BillOfLadingLabel,
      CloseLabel,
      ContactEmailLabel,
      ContactNameLabel,
      ContactPhoneLabel,
      CustomerLabel,
      CustomerInformationLabel,
      CustomerNumberLabel,
      DateShippedLabel,
      DescriptionLabel,
      EstimatedRushOrderFeeLabel,
      FlightItineraryLabel,
      FreightLabel,
      FreightAccountNumberLabel,
      FreightCompanyInformationLabel,
      InvoiceLabel,
      InvoiceInformationLabel,
      ItemShipmentDetailsLabel,
      JDESalesNumberLabel,
      LineLabel,
      OrderLabel,
      OrderedLabel,
      OrderedDateLabel,
      OrderAmountLabel,
      OrderInformationLabel,
      OrderLinesLabel,
      OrderTypeLabel,
      PackingSlipLabel,
      PackingSlipNumberLabel,
      PartLabel,
      PartTotalLabel,
      PNLabel,
      POLabel,
      ReasonForShippingMethodLabel,
      SerialNumberLabel,
      ShipmentsLabel,
      ShipmentMethodLabel,
      ShipmentTermsLabel,
      ShippedLabel,
      ShippedAmountLabel,
      ShippingAddressLabel,
      ShippingCompanyLabel,
      ShipDateLabel,
      StatusLabel,
      TotalLabel,
      TrackingInfoLabel,
      unitPriceLabel
    }
  
    @api recordId;
    invoiceid;
    isloading = true;
    orderLines;
    invoiceLines;
    partTotal = 0.00;
    freightTotal= 0.00;
    rushOrderTotal= 1.00;
    orderTotal= 0.00;
    shippedTotal=0;
    shippedOrderTotal=0;
    packingSlipNumber;
    shipmentItemsColumns = shipmentItemsColumns;
    shipmentscolumns = Shipmentscolumns;
  
    isCtmStorefront = false;
    isCtbrStorefront = false;
    isPpgStorefront = false;
  
    partNumber;
    partDescription;
    @track shipMentItems;
    isModalOpen = false;
    modalLoading = true;
    @track shipments;
    hasShipments=false;
    invoiceLogo = myResource;

    @track OrderItemLineTable;
    @track sortBy;
    @track sortDirection;

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
  
    //SHIPMETHOD_FIELD
    @wire(getRecord, { recordId:  "$recordId", fields: [SHIPMETHOD_FIELD] })
    ShipMethodValue;
  
     get ShipmentMethodValue() {
        return getFieldValue(this.ShipMethodValue.data, SHIPMETHOD_FIELD);
    }
  
    @wire(fetchOrderlines, {recordId: '$recordId' })
    OrderLineDetails({error,data}) {
      this.hasShipments=false;    
      if (data) {
        this.orderLines = data.orderItems;
        this.partTotal = data.partTotal + data.rushOrderTotal;
        this.freightTotal = data.freightTotal;
        this.rushOrderTotal = data.rushOrderTotal;
        this.orderTotal = data.orderTotal;
        this.shipments = data.shipments; 
        this.shippedTotal = data.shippedTotalValue;
  
        this.shippedOrderTotal=(this.shippedTotal+this.rushOrderTotal+this.freightTotal);
        if(this.shipments && this.shipments.length>0){
            this.hasShipments=true;
        }
        
        this.isloading = false;
        this.error = undefined;
  
        //determine shipment method fields
        console.log('Shipmetn Method data: ' + this.ShipmentMethodValue );
      } else if (error) {
        this.error = error;
      }
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
                                  ShippingCompanyName : row.Shipment.NATT_ShippingCompanyName__c,
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
                  name:'NATT_Invoice_Detail_Page__c'
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
    
    getWebstoreName(){
      getWebstore({communityId : communityId})
      .then(result => {
          console.log('Webstore Name: ' + result);
          if(result == 'CTM Storefront'){
            console.log('CTM STOREFRONT FOUND');
            this.isCtmStorefront = true;
            this.isCtbrStorefront = false;
            this.isPpgStorefront = false;
          }else if(result == 'CTBR Storefront'){
            this.isCtmStorefront = false;
            this.isCtbrStorefront = true;
            this.isPpgStorefront = false;
          }else{
            this.isCtmStorefront = false;
            this.isCtbrStorefront = false;
            this.isPpgStorefront = true;
          }
      })
      .catch(error => {
          console.log('price file failed to load: ' + error.body.message);
          this.error = error;
      })
          
    }
  
    connectedCallback(){
      this.getWebstoreName();
    }

    printDialog(){
        window.print();
    }
    
    handleClose(){         
        window.close();    
    }

    
  }