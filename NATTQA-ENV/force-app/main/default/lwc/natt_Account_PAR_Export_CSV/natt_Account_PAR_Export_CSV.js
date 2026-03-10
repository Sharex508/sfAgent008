import { LightningElement, track, api} from 'lwc';
// importing accounts
import getAccountList from '@salesforce/apex/NATT_ParExportToCsvController.getPARList';
import getAccountName from '@salesforce/apex/NATT_ParExportToCsvController.getAccountName';
// imported to show toast messages
import {ShowToastEvent} from 'lightning/platformShowToastEvent';

// datatable columns
const cols = [
    {label: 'PAR Name',fieldName: 'Name'}, 
    {label: 'Country',fieldName: 'NATT_Country__c'}, 
    {label: 'State',fieldName: 'NATT_State__c'},
    {label: 'County',fieldName: 'NATT_County__c'},
    {label: 'Trailer',fieldName: 'NATT_Trailer__c',type: 'boolean'}, 
    {label: 'Truck',fieldName: 'NATT_Truck__c',type: 'boolean'},
    {label: 'Special Products',fieldName: 'NATT_Special_Products__c',type: 'boolean'},
];

export default class NattAccountPARExportCSV extends LightningElement {

    @api recordId;
    @api accountId;
    @track error;
    @track data;
    @track columns = cols;
    @api spinner = false;
    @api message = false;
    @api datetoday ;
    @track recordName;
    
   
    // fetching accounts from server
    connectedCallback(){
        this.spinner = true;
        getAccountName({accId : this.accountId})
        .then(result => {
            this.recordName = result.Name;
        })

        getAccountList({accId : this.accountId})
        .then(result => {
            this.data = result;
            this.error = undefined;
            if(this.data.length > 0){
            this.downloadCSVFile();
            this.closeAction();
            }else{
                this.message = true;
                this.spinner = false;
            }
        })
        .catch(error => {
            this.error = error;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error while getting PAR list', 
                    message: error.message, 
                    variant: 'error'
                }),
            );
            this.data = undefined;
        });

    }

    // this method validates the data and creates the csv file to download
    downloadCSVFile() {  
        let rowEnd = '\n';
        let csvString = '';

        // this set elminates the duplicates if have any duplicate keys
        let rowData = new Set();

        // getting keys from data
        this.data.forEach(function (record) {
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
        for(let i=0; i < this.data.length; i++){
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
                    let value = this.data[i][rowKey] === undefined ? '' : this.data[i][rowKey];
                    csvString += '"'+ value +'"';
                    colValue++;
                }
            }
            csvString += rowEnd;
        }

        // Creating anchor element to download
        let downloadElement = document.createElement('a');
         
        //Renanme field api name with label 
        csvString = csvString.replace('NATT_State__c','State');
        csvString = csvString.replace('NATT_Country__c','Country');
        csvString = csvString.replace('NATT_County__c','County');
        csvString = csvString.replace('NATT_Trailer__c','Trailer');
        csvString = csvString.replace('NATT_Truck__c','Truck');
        csvString = csvString.replace('NATT_Special_Products__c','Special Products');

        csvString = csvString.replace('ReplaceCountryNull','');
        csvString = csvString.replace('ReplaceStateNull','');
        csvString = csvString.replace('ReplaceCountyNull','');
        
        //Get current date and format
        let date = new Date();
	    this.datetoday = date.getFullYear()+"-"+(date.getMonth()+1)+"-"+ date.getDate();

        // This  encodeURI encodes special characters, except: , / ? : @ & = + $ # (Use encodeURIComponent() to encode these characters).
        downloadElement.href = 'data:text/csv;charset=utf-8,' + encodeURI(csvString);
        downloadElement.target = '_self';
        // CSV File Name
        downloadElement.download = 'PAR List ('+this.recordName+','+this.datetoday +').csv';
        // below statement is required if you are using firefox browser
        document.body.appendChild(downloadElement);
        // click() Javascript function to download CSV file
        downloadElement.click(); 
    }
    
    //Event to call aura for quick action window disable
    closeAction(){ 
        this.spinner = false;
        const closeQA = new CustomEvent('close');
        // Dispatches the event.
        this.dispatchEvent(closeQA);
    }
}