import { LightningElement , wire , api } from 'lwc';
import { updateRecord } from 'lightning/uiRecordApi';
import { createRecord } from 'lightning/uiRecordApi';
import { getObjectInfo, getPicklistValuesByRecordType  } from 'lightning/uiObjectInfoApi';
import NATT_OBJECT from '@salesforce/schema/NATT_Address__c';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import userId from '@salesforce/user/Id';
import { getRecord } from 'lightning/uiRecordApi';
import AccountId from '@salesforce/schema/User.AccountId';


import upsertContactPointAddress from '@salesforce/apex/ContactPointAddressController.upsertContactPointAddress';

export default class DisplayNattAddresses extends LightningElement {
      isEditMode;
    createDropShip ='';
    contactPointAddressRtId;
    filteredStateOptions = [];
    name = '';
    street = '';
    selectedState = '';
    selectedCountry = '';
    postalCode = '';
    stateOptions = [];
    countryOptions = [];
    nattRecordTypeId;
    nattCPARecordTypeId;
    city;
    address;
    stateValues;
    stateControllerMap;
    effectiveAccountId;
    nameInputFocused = false;
    
    _record;
@api 
set record(value) {
    this._record = value;
    if (value) {
        this.isEditMode = true;
        this.name = value.Name || '';
        this.city = value.City || '';
        this.postalCode = value.PostalCode || '';
        this.address = value.Street || '';
        this.selectedCountry = value.Country || '';
        this.selectedState = value.State || '';
    } else {
        this.isEditMode = false;
    }
}

get record() {
    return this._record;
}

    
    get actionLabel() {
    return this.isEditMode ? 'Save' : 'Create New';
    }

    connectedCallback() { 
        console.log('Received record:', JSON.stringify(this.record)); 
        if (this.record) {
            this.isEditMode = true; 
        } else {
            this.isEditMode = false; 
        }
    }

    renderedCallback() {
        
        if (!this.nameInputFocused) {
            const nameInput = this.template.querySelector('[data-id="nameInput"]');
            if (nameInput) {
                nameInput.focus();
                this.nameInputFocused = true;
            }
        }
    }

    


    @wire(getRecord, { recordId: userId, fields : [AccountId]})
        wiredRecord({data,error}){
            if(data){
                this.effectiveAccountId = data.fields.AccountId.value;
                console.log('this.effectiveAccountId=>>'+this.effectiveAccountId);
                
            }
    }



    
 
    //Natt Address Record Type Id
      @wire(getObjectInfo, { objectApiName: NATT_OBJECT })
    objectInfo({ data, error }) {
        if (data) {
            const recordTypes = data.recordTypeInfos;
            for (let rtId in recordTypes) {
                if (recordTypes[rtId].name === 'NATT Address') {
                    this.nattRecordTypeId = rtId;
                    console.log('this.nattRecordTypeId=>>'+this.nattRecordTypeId);
                    break;
                }
            }
        } else if (error) {
            console.error('Error fetching object info:', error);
        }
    }

   


    

   @wire(getPicklistValuesByRecordType, { objectApiName: NATT_OBJECT, recordTypeId: '$nattRecordTypeId' }) // use hardcoded ID for now
    wiredPicklists({ data, error }) {
        if (data) {
            console.log('Picklist data received=>>'+JSON.stringify(data));
            const countryField = data.picklistFieldValues['NATT_Country__c'];
            console.log('countryField=>>:' +countryField);
            const stateField = data.picklistFieldValues['NATT_State_Province__c'];

            this.countryOptions = countryField.values;
            console.log('this.countryOptions=>>:' +this.countryOptions);
            this.stateControllerMap = stateField.controllerValues;
            console.log('this.stateControllerMap=>>:' +this.stateControllerMap);
            this.stateValues = stateField.values;
            console.log('this.stateValues=>>:' +this.stateValues);
        } else if (error) {
            console.error('Error loading picklists:', error);
        }if (this.selectedCountry) {
            this.filterStatesForSelectedCountry();
        }
     else if (error) {
        console.error('Error loading picklists:', error);
    }
        
    }

   handleCountryChange(event) {
    this.selectedCountry = event.detail.value;
    console.log('this.selectedCountry=>>'+this.selectedCountry);
    this.filterStatesForSelectedCountry();
    this.selectedState = '';
}

    
     handleStateChange(event) {
        this.selectedState = event.detail.value;
        console.log('this.selectedState=>>'+this.selectedState);
    }
   filterStatesForSelectedCountry() {
    if (this.selectedCountry && this.stateControllerMap && this.stateValues) {
        const controllingKey = this.stateControllerMap[this.selectedCountry];
        this.filteredStateOptions = this.stateValues.filter(
            option => option.validFor.includes(controllingKey)
        );
        this.stateRequired = this.filteredStateOptions.length > 0;
    } else {
        this.filteredStateOptions = [];
        this.stateRequired = false;
    }
}


    handleNameChange(event){
        this.name = event.detail.value;
        
        console.log('this.name=>>'+this.name);
    }

   

    handleCityChange(event){
        this.city = event.detail.value;
        console.log('this.city=>>'+this.city);
    }
    handlePostalCodeChange(event){
        this.postalCode = event.detail.value;
        console.log('this.postalCode=>>'+this.postalCode);
    }
    handleAddressChange(event){
        this.address = event.detail.value;
        console.log('this.address=>>'+this.address);
    }

   createAddressRecord() {
    if (this.name.length > 40) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: 'Name should not be greater than 40 characters.',
            variant: 'error'
        }));
        return;
    }
    

    if (this.stateRequired && !this.selectedState) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: 'State/Province is required for the selected country.',
            variant: 'error'
        }));
        return;
    }

    if (!this.selectedCountry) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: 'Country is required.',
            variant: 'error'
        }));
        return;
    }

    upsertContactPointAddress({
        recordId: this.record?.Id || null,
        name: this.name,
        street: this.address,
        state: this.selectedState,
        country: this.selectedCountry,
        postalCode: this.postalCode,
        city: this.city,
        parentId: this.effectiveAccountId
    })
    .then(recordId => {
       
        const message = this.record ? 'Drop Ship Address updated successfully!' : 'Drop Ship Address created successfully!';
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message,
            variant: 'success'
        }));

        /*const eventName = this.record ? 'addressupdated' : 'addresscreated';
        this.dispatchEvent(new CustomEvent(eventName));*/
        const eventName = this.record ? 'addressupdated' : 'addresscreated';
        this.dispatchEvent(new CustomEvent(eventName));

    })
    .catch(error => {
        console.error('Error saving address:', error);
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: 'Failed to save address.',
            variant: 'error'
        }));
    });
}


    handleCancel(){
       this.dispatchEvent(new CustomEvent('cancel'));
    }


}