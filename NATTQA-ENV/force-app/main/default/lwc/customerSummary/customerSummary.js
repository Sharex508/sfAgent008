import { LightningElement, track,wire,   api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
//import { CurrentPageReference } from 'lightning/navigation';
import modal from '@salesforce/resourceUrl/customModalCss';
import { loadStyle } from 'lightning/platformResourceLoader';
import getRecordDetails from'@salesforce/apex/CustomerSummaryController.getRecordDetails';
import updateRecord from'@salesforce/apex/CustomerSummaryController.updateRecord';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import { refreshApex } from '@salesforce/apex';
import { CloseActionScreenEvent } from 'lightning/actions';

const mapLabelToAPIName = {
    id : 'Id',
    dealerComment : 'EC_Dealer_Comments__c',      
    dealerSuppliedOption : 'EC_Dealer_Supplied_Options__c',
    warranty : 'EC_Warranty__c',
    performanceData : 'EC_Performance_Data__c',
    unit : 'EC_Unit__c',
    dealerInstalledOptions : 'EC_Dealer_Installed_Options__c',
    fuel : 'EC_Fuel__c',
    nonStandardOptions : 'EC_Non_Standard_Options__c',
    miscellaneousPrep : 'EC_Miscellaneous_Prep__c',
    installation : 'EC_Installation__c',
    applicableTaxes : 'EC_Applicable_Taxes__c',
    totalInstalledPackages : 'EC_Total_Installed_Packages__c'       
};
export default class CustomerSummary extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;   
    //@api orgUrl;
    @api title = 'Customer Summary';
    @track wiredResults = [];
    @track quoteObj=[];
    disabled = true;
    isEditable = true;
    booLoading = true;
    isPortalUser;
    //@wire(CurrentPageReference) pageRef;

    connectedCallback() {        
        loadStyle(this, modal);        
    }
    

    @wire(getRecordDetails,{
        recordId:'$recordId',
        objName: '$objectApiName'
    })
    wiredData(result) {
        this.wiredResults = result;
        if (result.data) {
            let response = JSON.parse(result.data);
            this.quoteObj = response; 
            this.isPortalUser = this.quoteObj.isPortalUser;
            this.booLoading = false;         
        }else if (result.error) {
            this.error = result.error;
            this.quoteObj = undefined;
        }
    }
    handleSaveRecord() {  
        this.booLoading = true;     
        const objectToUpdate = Object.create({});
        Object.keys(mapLabelToAPIName).forEach(item=>{        
        let apiname = mapLabelToAPIName[item];  
        objectToUpdate[apiname] = this.quoteObj[item];        
        })
        console.log('objectToUpdate:', objectToUpdate);

       updateRecord({ objJSON: JSON.stringify(objectToUpdate), objName: this.objectApiName })
            .then(result => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Records Saved Successfully',
                        variant: 'success'
                    })
                );
                console.log('Update successful:', result);
                this.booLoading = false;
            })
            .catch(error => {
                console.error('Update error:', error);
            });

        this.refreshRows();
    }
    handleEdit() {      
        this.isEditable = false; 
        this.refreshRows();
    }

    closeAction() {
        console.log('closeModal clicked');        
        this.dispatchEvent(new CloseActionScreenEvent());
        const selectedRecordEvent = new CustomEvent(
            'closemodal'
        );
        this.dispatchEvent(selectedRecordEvent);
        this.refreshRows();
    }

    handleInputChange(event) {
        const {name,value} = event.target;
        this.quoteObj[name]=value;
        console.log('quoteObj:', this.quoteObj[name]);
    }

    handleButtonClick() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'File Downloaded Successfully',
                variant: 'success'
            })
        );
        let urlPrefix;
        if(this.isPortalUser) {
            urlPrefix = '/carriersolutioncenter/apex/CustomerSummaryDocumentOnQuote?id=';
        } else {
            urlPrefix = '/apex/CustomerSummaryDocumentOnQuote?id=';
        }
        window.open(urlPrefix + this.recordId + '&objAPI=' + this.objectApiName, '_blank');
        this.refreshRows();
    }

    refreshRows() {
        refreshApex(this.wiredResults);
    }
}