import { LightningElement ,api,track, wire} from 'lwc';
import CASELINEITEM_OBJECT from '@salesforce/schema/NATT_Case_Sales_Order__c';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import createPerfPartReturnInternal from '@salesforce/apex/NAC_CreateCaseController.createPerfPartReturnInternal';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';


export default class Nac_CreateCaseLineItem extends NavigationMixin(LightningElement) {

    @track perfPartReturnProductList = [];
    perfPartaddMoreItemLabel = 'Add Items';
    showSpinner = false;
    objectApiName = 'Case';
    @api recordId;
    perfPartheaderCheckBox = false;
    perfPartdisableClearSelectedButton = true;
    isSaveDisabled = true;

    @wire(getObjectInfo, { objectApiName: CASELINEITEM_OBJECT})
    caseLineItemObjectInfo

    classMap = {
        size1: "slds-col slds-p-around_xx-small slds-size_1-of-12",
        size2: "slds-col slds-p-around_xx-small slds-size_2-of-12",
        size3: "slds-grid slds-p-around_xx-small slds-size_1-of-12",
        size4: "slds-col slds-size_1-of-12",
    }
    get columnHeaderPerformance() {
        return [
            { label: "Carrier Order#", class: this.classMap.size4, showCheckbox: true,showToolTip:true },
            { label: "PO#", class: this.classMap.size1, showCheckbox: false,showToolTip:true  },
            { label: "Part #", class: this.classMap.size1, showCheckbox: false,showToolTip:true  },
            { label: "Part # (Not tied to Order)", class: this.classMap.size1,showCheckbox: false, showToolTip:false},
            { label: "Shipment #", class: this.classMap.size1, showCheckbox: false, showToolTip:false  },
            { label: "Line", class: this.classMap.size1, showCheckbox: false,showToolTip:false },
            { label: "Disputed Quantity #", class: this.classMap.size1, showCheckbox: false,showToolTip:true  },
            { label: "Model/Serial #", class: this.classMap.size2, showCheckbox: false,showToolTip:false },
            { label: "Additional Detail/Customer Comments", class: this.classMap.size2, showCheckbox: false,showToolTip:true },
            { label: "Action", class: this.classMap.size1, showCheckbox: false,showToolTip:false },
        ];
    }

    connectedCallback(){
        try{
            
            this.createNewCaseLineItem();
        }catch(ex){
            console.log('Error Occurred:');
            console.log(ex);
        }
    }

    createNewCaseLineItem(){
        try{           
            this.showSpinner=true;            
            this.perfPartReturnProductList.push({
                Id:'',
                recordDetails: '',
                checkbox: false,
                value: [                   
                    { label: 'NATT_JDE_SO__c', value: '', isEditable: true, type: 'text',isCombobox:false, isdelete: false, class: this.classMap.size3, showCheckbox: true, required: true,maxlength: this.caseLineItemObjectInfo.data.fields.NATT_JDE_SO__c.length },
                    { label: 'NAC_Purchase_Order_Number__c', value: '', isEditable: true, type: 'text',isCombobox:false, isdelete: false, class: this.classMap.size1, showCheckbox: false, required: true, maxlength: this.caseLineItemObjectInfo.data.fields.NAC_Purchase_Order_Number__c.length },
                    { label: 'NATT_Part__c', value: '', isEditable: true, type: 'text',isCombobox:false, isdelete: false, class: this.classMap.size1, showCheckbox: false, required: true, maxlength: this.caseLineItemObjectInfo.data.fields.NATT_Part__c.length },
                    { label: 'NAC_Part_Not_tied_to_Order__c', value: '', isEditable: true, type: 'text',isCombobox:false, isdelete: false, class: this.classMap.size1, showCheckbox: false, required: false,maxlength: this.caseLineItemObjectInfo.data.fields.NAC_Part_Not_tied_to_Order__c.length},
                    { label: 'NATT_Packing_Slip_Number__c', value: '', isEditable: true, type: 'text',isCombobox:false, isdelete: false, class: this.classMap.size1, showCheckbox: false, required: false, maxlength: this.caseLineItemObjectInfo.data.fields.NATT_Packing_Slip_Number__c.length },
                    { label: 'NAC_Line_Number__c', value: '', isEditable: true, type: 'text',isCombobox:false, isdelete: false, class: this.classMap.size1, showCheckbox: false, required: false, maxlength: this.caseLineItemObjectInfo.data.fields.NAC_Line_Number__c.length },
                    { label: 'NATT_Disputed_Quantity__c', value: 0, isEditable: true, type: 'number',isCombobox:false, isdelete: false, class: this.classMap.size1, showCheckbox: false, required: true, maxlength: this.caseLineItemObjectInfo.data.fields.NATT_Disputed_Quantity__c.length },
                    { label: 'NATT_Serial_Number__c', value: '', isEditable: true, type: 'text',isCombobox:false, isdelete: false, class: this.classMap.size2, showCheckbox: false, required: false, maxlength: this.caseLineItemObjectInfo.data.fields.NATT_Serial_Number__c.length },
                    { label: 'NATT_Additional_Detail__c', value: '', isEditable: true, type: 'text',isCombobox:false, isdelete: false, class: this.classMap.size2, showCheckbox: false, required: true },
                    { label: 'deleteIcon', isEditable: false, type: 'icon', isdelete: true,isCombobox:false, class: this.classMap.size1, showCheckbox: false, required: false },
                ],
            });
            console.log(this.perfPartReturnProductList.length);
            for(let i=0;i< this.perfPartReturnProductList.length; i++){
                this.perfPartReturnProductList[i].Id = i;                
            }
            console.log(JSON.stringify(this.perfPartReturnProductList));
            this.perfPartaddMoreItemLabel = 'Add More Items';
            this.showSpinner=false;            
            this.isSaveDisabled=true;
        }catch(Ex){
            console.log(Ex);

        }
    }

    pphandleFieldChange(event) {
       
        this.isSaveDisabled = false;
        console.log(event.currentTarget.dataset.id);
        this.perfPartReturnProductList.forEach(prod => {
            //CXREF- 4009 Changes Starts
                 prod.value.forEach(field => {
                     if (prod.Id == event.currentTarget.dataset.id) {
                         if (field.label == event.currentTarget.dataset.fieldname) {
                             field.value = event.currentTarget.value;
                         }
                     }
                     if (field.value == '' && (field.label == 'NATT_JDE_SO__c' || field.label == 'NAC_Purchase_Order_Number__c' || field.label == 'NATT_Part__c' || field.label == 'NATT_Disputed_Quantity__c' || field.label == 'NATT_Additional_Detail__c')) {
                        
                         this.template.querySelector('[data-id="' + prod.Id + '"][data-fieldname="' + field.label + '"]').classList.add('slds-has-error');
                         this.isSaveDisabled = true;
                         
                     } else if(field.value != '' && (field.label == 'NATT_JDE_SO__c' || field.label == 'NAC_Purchase_Order_Number__c' || field.label == 'NATT_Part__c' || field.label == 'NATT_Disputed_Quantity__c' || field.label == 'NATT_Additional_Detail__c')) {
                        this.template.querySelector('[data-id="' + prod.Id + '"][data-fieldname="' + field.label + '"]').classList.remove('slds-has-error');
                    }
                     
                 })
            //CXREF- 4009 Changes Ends
         });
        console.log(JSON.stringify(this.perfPartReturnProductList));
    }

    handleLoad() {
        window.clearTimeout(this.delayTimeout);
        this.delayTimeout = setTimeout(() => {
            this.showSpinner = false;
        }, DELAY);
    }

    ppdeleteRow(event){
        let tempList = this.perfPartReturnProductList.filter(prod => prod.Id != event.currentTarget.dataset.id);
        this.perfPartReturnProductList = tempList;
        if(this.perfPartReturnProductList.length > 0){
            this.perfPartaddMoreItemLabel = 'Add More Items';
        }else{
            this.perfPartaddMoreItemLabel = 'Add Items';
        }

        if(this.perfPartReturnProductList.length == 0){
            this.isSaveDisabled=true;
        }

    }
    closeModal(){
        this.dispatchEvent(new CloseActionScreenEvent());

    }

    perfPartSubmitCase() {       
        try{
        let returnItemFieldList = [];
        this.perfPartReturnProductList.forEach(prod => {
            let returnItemField = {};
            //returnItemField.NATT_Product__c	= prod.Id;
            prod.value.forEach(field => {
                if(field.isEditable){
                    returnItemField[field.label] = field.value;
                }
            })
            returnItemFieldList.push(returnItemField);
        });
        
        this.showSpinner = true;
        createPerfPartReturnInternal({ caseField: this.caseFields, returnItemFields: returnItemFieldList, caseId:this.recordId })
            .then(result => {
                this.showSpinner = false;
                try {
                    if (result.hasError) {
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Error',
                                message: result.errorMessage,
                                variant: 'error',
                                mode: 'dismissable'
                            })
                        );
                    } else {
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Success',
                                message: 'Case Line Item created succesfully.',
                                variant: 'success',
                                mode: 'dismissable'
                            })
                        );
                        this.therefreshPage();
                        this.dispatchEvent(new CloseActionScreenEvent());
                        
                        
                    }
                }
                catch (error) {
                    console.log(JSON.stringify(error.message));
                }
            })
            .catch(error => {
                this.showSpinner = false;
                console.log('Error' + JSON.stringify(error));
            });
            
        }catch(ex){
            console.log(ex);
        }
    }

    therefreshPage(){
        setTimeout(() => {
            eval("$A.get('e.force:refreshView').fire();");
       }, 1000); 
    }

    handleClearSelectedPerformancePart() {
        let tempList = this.perfPartReturnProductList.filter(prod => !prod.checkbox);
        this.perfPartReturnProductList = tempList;
        this.perfPartaddMoreItemLabel = 'Add Items';
        this.perfPartheaderCheckBox = false;
        this.template.querySelector('[data-id="ppheaderCheckBox"]').checked = this.perfPartheaderCheckBox;
        this.perfPartdisableClearSelectedButton = true;

        if(this.perfPartReturnProductList.length == 0){
            this.isSaveDisabled=true;
        }

    }

    perfPartHandleCheckAll(event) {
        this.perfPartheaderCheckBox = event.target.checked;
        this.perfPartdisableClearSelectedButton = !event.target.checked;
        this.perfPartReturnProductList.forEach(prod => {
            prod.checkbox = event.target.checked;
            this.template.querySelector('[data-id="' + prod.Id + '"]').checked = prod.checkbox;
        });
    }

    pphandleCheck(event) {
        this.perfPartdisableClearSelectedButton = true;
        this.perfPartheaderCheckBox = true;
        this.perfPartReturnProductList.forEach(prod => {
            if (prod.Id == event.currentTarget.dataset.id) {
                prod.checkbox = event.target.checked;
            }
            if (prod.checkbox) {
                this.perfPartdisableClearSelectedButton = false;
            } else {
                this.perfPartheaderCheckBox = false;
            }
        });
        this.template.querySelector('[data-id="ppheaderCheckBox"]').checked = this.perfPartheaderCheckBox;
    }

    handleSubmit(event) {
        event.preventDefault();
        
        
    }
}