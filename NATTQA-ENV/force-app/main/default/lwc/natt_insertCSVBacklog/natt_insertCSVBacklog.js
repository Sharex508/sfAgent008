import { LightningElement, track, api } from 'lwc';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import csvFileRead from '@salesforce/apex/CSVFileReadLWCCntrl.csvFileRead';

const columnsBacklog = [
    { label: 'Prod No', fieldName: 'NATT_Prod_No__c' }, 
    { label: 'Prod Description', fieldName: 'NATT_Prod_Description__c' },
    { label: 'Bill To Address', fieldName: 'NATT_Bill_To_Address__c'},
    {label : 'Account', fieldName : 'NATT_Account__c'}, 
    { label: 'Bill To Name', fieldName: 'NATT_Bill_To_Name__c'}, 
    { label: 'End User', fieldName: 'NATT_End_User__c'},
    { label: 'Customer P.O.', fieldName: 'NATT_Customer_PO__c'},
    { label: 'Region', fieldName: 'NATT_Region__c' },
    { label: 'SOLine', fieldName: 'NATT_SOLine__c'},
    { label: 'Order Type', fieldName: 'NATT_Order_Type__c' },
    { label: 'Sch Pick Date', fieldName: 'NATT_Sch_Pick_Date__c'},
    { label: 'BklgQty', fieldName: 'NATT_BklgQty__c' },
    { label: 'Req Ship Date', fieldName: 'NATT_Req_Ship_Date__c' },
    //Hold Code need to ask User what field is mapped in Backlog object
    //{ label: 'Hold Code', fieldName: '' },
    { label: 'Freight Code', fieldName: 'NATT_Freight_Code__c' },
    { label: 'Ship To City', fieldName: 'NATT_Ship_To_City__c'},
    { label: 'Ship To State', fieldName: 'NATT_Ship_To_State__c' },
    { label: 'SO Cat.', fieldName: 'NATT_SO_Cat__c'},
    { label: 'Prod Family', fieldName: 'NATT_Prod_Family__c'},
    { label: 'Prod Line', fieldName: 'NATT_Prod_Line__c'}

    
];

export default class cSVFileReadLWC extends LightningElement {
    @api recordId;
    @track error;
    @track columnsBacklog = columnsBacklog;
    @track data;

    // accepted parameters
    get acceptedCSVFormats() {
        return ['.csv'];
    }
    
    uploadFileHandler(event) {
        // Get the list of records from the uploaded files
        const uploadedFiles = event.detail.files;

        // calling apex class csvFileread method
        csvFileRead({contentDocumentId : uploadedFiles[0].documentId})
        .then(result => {
            window.console.log('result ===> '+result);
            this.data = result;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success!!',
                    message: 'Backlog records are created according to the CSV file upload!!!',
                    variant: 'Success',
                }),
            );
        })
        .catch(error => {
            this.error = error;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error!!',
                    message: 'Some unexpected error',
                    variant: 'error',
                    mode: 'dismisable'
                }),
            );     
        })

    }
}