import { LightningElement,wire,track} from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getShipment from '@salesforce/apex/NATT_ShipmentDetailsCon.getShipment';
import getTrackinginfo from '@salesforce/apex/NATT_ShipmentDetailsCon.getTrackinginfo';
import myResource from '@salesforce/resourceUrl/CarrierTransicoldPartsnetLogo'

export default class Natt_ShipmentDetails extends LightningElement {
    recordId;
    partsnet = myResource + '/logos/partsnet.jpg';
    shipment;    
    CurrentPageReference = null;
    partTotal=0;
    freightTotal=0;
    rushOrderFeeTotal=0;
    grandTotal=0;
    shipmentLines;
    @track trackingnumber;
    @track trackingUrl;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
       if (currentPageReference) {
          this.recordId = currentPageReference.state.recId;          
       }
    }
    

    @wire (getShipment,{shipmentId: '$recordId'}) 
    wiredShipment({ data, error }) {
        console.log('called with:'+this.recordId);
        if (data) {
            console.log('data:'+JSON.stringify(data));
            this.shipment = data;
            this.trackingnumber = this.shipment.TrackingNumber;
            this.shipmentLines = this.shipment.ShipmentItems;
            let tempLines=[];
            this.shipmentLines.forEach((sLine)=>{                
                console.log('line:'+JSON.stringify(sLine));
                if(sLine.NATT_OrderProduct__r.TypeCode==='Charge' && sLine.NATT_OrderProduct__r.Type==='Delivery Charge'){    
                    console.log('charge');
                    if(sLine.NATT_OrderProduct__r.Product2.Name.includes('Rush Fee')){
                        console.log('chargeRush');
                        this.rushOrderFeeTotal+=sLine.NATT_Amount__c;                        
                    }
                    if(sLine.NATT_OrderProduct__r.Product2.Name.includes('Freight')){
                        console.log('chargeFreight');
                        this.freightTotal+=sLine.NATT_Amount__c;
                    }                    
                }else{    
                    tempLines.push(sLine);        
                    this.partTotal+=sLine.NATT_Amount__c;
                }                
            });
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
    @wire (getTrackinginfo,{shipmentId: '$recordId'}) 
    wiredTrackingInfo({ data, error }) {
        if (data) {
            this.trackingUrl = data;
        }
        else{
            this.trackingUrl = '//';
        }
        console.log('data----->:'+data);
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
/*
    _flatten(target, obj, path) {
        var i, empty;
        if (obj.constructor === Object) {
            empty = true;
            for (i in obj) {
                empty = false;
                this._flatten(target, obj[i], path ? path + '.' + i : i);
            }
            if (empty && path) {
                target[path] = {};
            }
        } else if (obj.constructor === Array) {
            i = obj.length;
            if (i > 0) {
                while (i--) {
                    this._flatten(target, obj[i], path + '[' + i + ']');
                }
            } else {
                target[path] = [];
            }
        } else {
            target[path] = obj;
        }
    }

    flatten(data) {
        var result = {};
        this._flatten(result, data, null);
        return result;
    }*/
}