import { api, LightningElement, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import ORDERNUM_FIELD from '@salesforce/schema/Order.OrderNumber';
import fetchOrderlines from '@salesforce/apex/NAC_ShipmentController.fetchOrderlines';
import fetchShipmentItems from '@salesforce/apex/NAC_ShipmentController.fetchShipmentItems';
import fetchShipmentItemList from '@salesforce/apex/NAC_ShipmentController.fetchShipmentItemList';


const shipmentItemsColumns = [
    { label: 'Ship Date', fieldName: 'ShipmentDate', },
    { label: 'Invoice #', fieldName: 'Invoice' },
    { label: 'Ordered ', fieldName: 'Ordered' },
    { label: 'Shipped ', fieldName: 'Quantity' },
    /* { label: 'Amount  ', fieldName: 'NATT_Amount__c', type: 'currency' }, */
    { label: 'Packing Slip', fieldName: 'PackingSlip' },
    { label: 'Tracking Info', fieldName: 'TrackingNum' },
    { label: 'Shipping Company', fieldName: 'ShippingCompanyName' },
    { label: 'Bill of Lading', fieldName: 'BillOfLading' }
];

const Shipmentscolumns = [
    {label: 'Invoice #', fieldName: 'NATT_InvoiceNumber__c',type: "button",
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
    { label: 'Packing Slip', fieldName: 'NATT_PackingSlipNumber__c' },
    { label: 'Ship Date', fieldName: 'NATT_DateShipped__c',
        type: 'date',
        typeAttributes:{
            year: "numeric",
            month: "2-digit",
            day: "2-digit",
            timeZone:"UTC"
    }
    },
    { label: 'Tracking Info', fieldName: 'TrackingNumber'},
    { label: 'Shipping Company', fieldName: 'NATT_ShippingCompanyName__c'},
    { label: 'Bill Of Lading', fieldName: 'NATT_BillOfLading__c'},
  ];

  const shipmentItemsListColumns = [
       
    { label: 'Product #', fieldName: 'Product'},
    { label: 'Description ', fieldName: 'Description' },
    { label: 'Quantity Shipped  ', fieldName: 'ShippedQty' },
    { label: 'Price', fieldName: 'Price',type: 'currency' },
    
  ];

export default class NacOrderShipmentDetails extends LightningElement {
    @api recordId;
    
    isloading = true;
    orderLines;
    invoiceLines;
    partTotal = 0.00;
    freightTotal = 0.00;
    rushOrderTotal = 0.00;
    orderTotal = 0.00;
    shippedTotal = 0;
    shippedOrderTotal = 0;
    packingSlipNumber;
    shipmentItemsColumns = shipmentItemsColumns;
    shipmentItemsListColumns = shipmentItemsListColumns;
    shipmentscolumns = Shipmentscolumns;
    partNumber;
    partDescription;
    @track shipMentItems;
    @track invoiceItems;
    isModalOpen = false;
    isInvoiceModalOpen =false;
    modalLoading = true;
    @track shipments;
    hasShipments = false;
    clickedInvoiceNumber ='';

    @track OrderItemLineTable;
    @track sortBy;
    @track sortDirection;

    

    @wire(getRecord, { recordId: "$recordId", fields: [ORDERNUM_FIELD] })
    OrderNum;

    get OrderNumber() {
        return getFieldValue(this.OrderNum.data, ORDERNUM_FIELD);
    }

    @wire(fetchOrderlines, { recordId: "$recordId" })
    OrderLineDetails({ error, data }) {
        console.log(data);
        console.log(this.recordId);
        
        this.hasShipments = false;
        if (data) {
            this.orderLines = data.orderItems;
            this.partTotal = data.partTotal;
            this.freightTotal = data.freightTotal;
            this.rushOrderTotal = data.rushOrderTotal;
            this.orderTotal = data.orderTotal;
            this.shipments = data.shipments;
            console.log('this.shipments');
            console.log(JSON.stringify(this.shipments));
            this.shippedTotal = data.shippedTotalValue;

            this.shippedOrderTotal = (this.shippedTotal + this.rushOrderTotal + this.freightTotal);
            if (this.shipments && this.shipments.length > 0) {
                this.hasShipments = true;
            }

            this.isloading = false;
            this.error = undefined;
        } else if (error) {
            this.error = error;
        }
    }

    openModal(event) {
        // to open modal set isModalOpen tarck value as true
        this.modalLoading = true;
        this.isModalOpen = true;
        var shipmentId = event.currentTarget.id.substring(0, 18);
        fetchShipmentItems({ recordId: shipmentId })
            .then(result => {
                this.partNumber = result.partNum;
                this.partDescription = result.description;
                if (result.shipmentItems) {
                    let tempRecords = JSON.parse(JSON.stringify(result.shipmentItems));
                    tempRecords = tempRecords.map(row => {
                        return {
                            ...row,
                            ShipmentDate: row.Shipment.NATT_DateShipped__c,
                            Invoice: row.Shipment.NATT_InvoiceNumber__c,
                            Ordered: row.NATT_OrderProduct__r.Quantity,
                            PackingSlip: row.Shipment.NATT_PackingSlipNumber__c,
                            TrackingNum: row.Shipment.TrackingNumber,
                            ShippingCompanyName: row.Shipment.NATT_ShippingCompanyName__c,
                            BillOfLading: row.Shipment.NATT_BillOfLading__c
                        };
                    })
                    this.shipMentItems = tempRecords;
                    
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

    callRowAction(event ) {
        this.isInvoiceModalOpen = true;
        //this.clickedInvoiceNumber =
        const recId =  event.detail.row.Id;
        const actionName = event.detail.action.name;
        console.log(recId);
        console.log(actionName);
        this.modalLoading = true;
        fetchShipmentItemList({ recordId: recId })
            .then(result => {
                try{ 
                
                this.clickedInvoiceNumber = result.invoiceNum;                
                if (result.shipmentItems) {
                    let tempRecords = JSON.parse(JSON.stringify(result.shipmentItems));
                    tempRecords = tempRecords.map(row => {
                        return {
                            ...row,
                            ShippedQty: row.NATT_OrderProduct__r.NATT_Shipped_Quantity__c,
                            Product: row.NATT_P_N__c,
                            Description: row.NATT_Product_Name__c,
                            Price: row.NATT_Amount__c
                           
                        };
                    })
                    this.invoiceItems = tempRecords;
                    
                }
                this.modalLoading = false;
                this.error = undefined;
                }catch(ex){
                    console.log('Error Message: '+ex);
                }
            })
            .catch(error => {
                this.error = error;
                this.modalLoading = false;
            });
        
       
    }
    closeModal() {
        // to close modal set isModalOpen tarck value as false      
        this.isModalOpen = false;
        this.partNumber = null;
        this.partDescription = null;
        this.shipMentItems = null;
    }
    closeInvoiceModal() {
        // to close modal set isModalOpen tarck value as false
        this.isInvoiceModalOpen = false;
        this.invoiceItems = null;
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
        let isReverse = direction === 'asc' ? 1 : -1;
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