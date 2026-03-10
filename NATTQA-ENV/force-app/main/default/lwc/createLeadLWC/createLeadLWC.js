import { LightningElement, wire } from 'lwc';
import usaStates from '@salesforce/label/c.USA_State_List';
import otherStates from '@salesforce/label/c.Other_State_List';
import roles from '@salesforce/label/c.Role_List';
import createLead from '@salesforce/apex/LeadController.createLead';
import CARRIER_LOGO from '@salesforce/resourceUrl/CarrierLogo';

import LEAD_OBJECT from '@salesforce/schema/Lead';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';

export default class CreateLeadLWC extends LightningElement {
    carrierLogo = CARRIER_LOGO;
    sendingBusinessOptions = [];
    receivingBusinessOptions = [];
    industryOptions = [];
    allSolutionsInterestedOptions = [];
    solutionsInterestedOptions = [];
    contactDetailOptions=[];
    customerDetailOptions=[];
    address = {};
    addCountry = '';
    error;
    disableSolutions = true;
    disableRB = true;
    disableOther = true;
    controlValuesSol;
    controlValRB;
    disableTitleOther = true;
    usaStatesList = usaStates.split(',');
    otherStatesList = otherStates.split(',');
    rolesList = roles.split(',');

    solutionSelected = [];

    @wire(getObjectInfo, { objectApiName: LEAD_OBJECT })
    objectInfo;

    // Picklist values based on record type
    @wire(getPicklistValuesByRecordType, { objectApiName: LEAD_OBJECT, recordTypeId: '$objectInfo.data.defaultRecordTypeId'})
    picklistValues({error, data}) {
        if(data) {
            this.error = undefined;
            if(data) {
                this.industryOptions = data.picklistFieldValues.Industry.values;
                this.sendingBusinessOptions = data.picklistFieldValues.Sending_Business__c.values;
                this.controlValRB = data.picklistFieldValues.Receiving_Business__c.controllerValues;
                this.allReceivingBusinessOptions = data.picklistFieldValues.Receiving_Business__c.values;
                this.controlValuesSol = data.picklistFieldValues.Solutions_Interested__c.controllerValues;
                this.allSolutionsInterestedOptions = data.picklistFieldValues.Solutions_Interested__c.values;
                this.contactDetailOptions = data.picklistFieldValues.Contact_Details__c.values;
                this.customerDetailOptions = data.picklistFieldValues.Customer_Details__c.values;
            }
            else if(error) {
                window.console.log('error =====> '+JSON.stringify(error));
            }
            
        }
        else if(error) {
            this.error = JSON.stringify(error);
        }
    }

    handleSBChange(event){
        let selectedSB = event.target.value;
        let validforNum = this.controlValRB[selectedSB];
        this.receivingBusinessOptions = [];
        this.allReceivingBusinessOptions.forEach(val => {
            if(val.validFor.includes(validforNum)) {
                this.receivingBusinessOptions = [...this.receivingBusinessOptions,val];
            }
        })
        if(this.receivingBusinessOptions.length>0){
            this.disableRB = false;
        }else{
            this.disableRB = true;
        }
    }


    handleRBChange(event){
        let selectedRB = event.target.value;
        let validforNum = this.controlValuesSol[selectedRB];
        this.solutionsInterestedOptions = [];
        this.allSolutionsInterestedOptions.forEach(val => {
            if(val.validFor.includes(validforNum)) {
                this.solutionsInterestedOptions = [...this.solutionsInterestedOptions,val];
            }
        })
        if(this.solutionsInterestedOptions.length>0){
            this.disableSolutions = false;
        }else{
            this.disableSolutions = true;
        }
    }

    handleCustomerDetailChange(event){
        if(event.detail.value==='Other'){
            this.disableOther=false;
        }else{
            this.disableOther=true;
        }
    }

    handleRoleChange(event){
        if(event.detail.value==='Other'){
            this.disableTitleOther=false;
        }else{
            this.disableTitleOther=true;
        }
    }

    get getStateOptions() {
        let statesList = [];
        let allStates = [...this.usaStatesList];
        this.otherStatesList.forEach(state => {
            allStates = [...allStates, state];
        });
        console.log('allStates',allStates);
        for(let i=0; i<allStates.length; i++ ){
            statesList.push({ label: allStates[i], value: allStates[i] });
        }
        return statesList;
    }

    get roleOptions() {
        let rolesOp = [];
        for(let i=0; i<this.rolesList.length; i++ ){
            rolesOp.push({ label: this.rolesList[i], value: this.rolesList[i] });
        }
        return rolesOp;
    }

    handleSolutionChange(event) {
        this.solutionSelected = event.detail.value;
        console.log(this.solutionSelected);
    }

    handleAddressChange(event){
        this.address.street = event.detail.street;
        this.address.city = event.detail.city;
        this.address.country = event.detail.country;
        this.address.state = event.detail.province;
        if(this.usaStatesList.includes(this.address.state)){
            this.addCountry = 'USA';
        }else{
            this.addCountry = '';
        }
        this.address.zip = event.detail.postalCode;
        this.stateCityRequired();
        
    }

    stateCityRequired(){
        const add = this.template.querySelector('lightning-input-address');
        if (!this.address.state) {
            add.setCustomValidityForField('Complete this field', 'province');
        } else {
            add.setCustomValidityForField('', 'province');
        }
        if (!this.address.city) {
            add.setCustomValidityForField('Complete this field', 'city');
        } else {
            add.setCustomValidityForField('', 'city');
        }
    }

    createLeadRec(){
        this.stateCityRequired();
        const allValidInput = [...this.template.querySelectorAll('lightning-input')]
        .reduce((validSoFar, inputCmp) => {
                    inputCmp.reportValidity();
                    return validSoFar && inputCmp.checkValidity();
        }, true);

        const allValidCombobox = [...this.template.querySelectorAll('lightning-combobox')]
        .reduce((validSoFar, inputCmp) => {
                    inputCmp.reportValidity();
                    return validSoFar && inputCmp.checkValidity();
        }, true);

        const allDualList = [...this.template.querySelectorAll('lightning-dual-listbox')]
        .reduce((validSoFar, inputCmp) => {
                    inputCmp.reportValidity();
                    return validSoFar && inputCmp.checkValidity();
        }, true);

        const allAddress = [...this.template.querySelectorAll('lightning-input-address')]
        .reduce((validSoFar, inputCmp) => {
                    inputCmp.reportValidity();
                    return validSoFar && inputCmp.checkValidity();
        }, true);

        
        if (allValidInput && allValidCombobox && allDualList && allAddress) {
            let objLead = { 'sobjectType': 'Lead' };
            objLead.Sender_Name__c = this.template.querySelector("[data-field='Sender_Name']").value;
            objLead.Sender_Email__c = this.template.querySelector("[data-field='Sender_Email']").value;
            objLead.Sender_Phone__c = this.template.querySelector("[data-field='Sender_Phone']").value;
            objLead.Sending_Business__c = this.template.querySelector("[data-field='Sending_Business']").value;
            objLead.Receiving_Business__c = this.template.querySelector("[data-field='Receiving_Business']").value;
            objLead.Customer_Discussion_Date__c = this.template.querySelector("[data-field='Customer_Discussion_Date']").value;
            objLead.Company = this.template.querySelector("[data-field='Company']").value;
            objLead.Street = this.address.street;
            objLead.Country = this.address.country;
            objLead.City = this.address.city;
            objLead.State = this.address.state;
            objLead.PostalCode = this.address.zip;
            objLead.Industry = this.template.querySelector("[data-field='Industry']").value;
            objLead.FirstName = this.template.querySelector("[data-field='FirstName']").value;
            objLead.LastName = this.template.querySelector("[data-field='LastName']").value;
            
            if(this.template.querySelector("[data-field='Title']").value === 'Other'){
                objLead.Title = this.template.querySelector("[data-field='Title']").value;
                objLead.Title = objLead.Title + ' - ';
                objLead.Title = objLead.Title + this.template.querySelector("[data-field='Title_Other']").value;
            }else{
                objLead.Title = this.template.querySelector("[data-field='Title']").value;
            }
            objLead.Email = this.template.querySelector("[data-field='Email']").value;
            objLead.Phone = this.template.querySelector("[data-field='Phone']").value;
            if(this.template.querySelector("[data-field='Customer_Detail']").value === 'Other'){
                objLead.Customer_Details__c = this.template.querySelector("[data-field='Customer_Detail_Other']").value;
            }else{
                objLead.Customer_Details__c = this.template.querySelector("[data-field='Customer_Detail']").value;
            }
            objLead.Contact_Details__c = this.template.querySelector("[data-field='Contact_Detail']").value;
            objLead.Customer_Interest__c = this.template.querySelector("[data-field='Customer_Interest']").value;
            objLead.Customer_Budget__c = this.template.querySelector("[data-field='Customer_Budget']").value;
            objLead.Solutions_Interested__c = this.template.querySelector("[data-field='Solutions_Interested']").value;
            objLead.LeadSource = 'Healthy Buildings - SPIFF';
            
            createLead({objLeadRec : objLead})
            .then(result => {
                console.log('From Apex:',result);
                if(result.includes('ERROR:')){
                    alert(result);
                }else{
                    alert('Thank You!! Your Lead has been successfully generated. We will reach out to you shortly.');
                    window.location.reload();
                }
            })
            .catch(error => {
                this.error = error;
                alert(JSON.stringify(error));
            })
        } else {
        }
    }

}