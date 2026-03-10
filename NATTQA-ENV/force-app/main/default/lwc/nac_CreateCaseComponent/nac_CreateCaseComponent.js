import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import CASE_OBJECT from '@salesforce/schema/Case';
import RETURNITEM_OBJECT from '@salesforce/schema/NATT_Return_Item__c';
import CASELINEITEM_OBJECT from '@salesforce/schema/NATT_Case_Sales_Order__c';
import IS_WARRANTY_FIELD from '@salesforce/schema/NATT_Return_Item__c.NAC_Is_Warranty__c';
import { getListUi } from 'lightning/uiListApi';
import getCaseDetails from '@salesforce/apex/NAC_CreateCaseController.getCaseDetails';
import createCoreReturns from '@salesforce/apex/NAC_CreateCaseController.createCoreReturns';
import createPerfPartReturns from '@salesforce/apex/NAC_CreateCaseController.createPerfPartReturns';
import Continue from '@salesforce/label/c.nac_Continue';
import okLabel from '@salesforce/label/c.nac_OkLabel';
import cancelLabel from '@salesforce/label/c.nac_CancelLabel';
import performancePartLabel from '@salesforce/label/c.nac_Case_Record_Type_Label_for_Performance_Part';
import coreReturnLabel from '@salesforce/label/c.nac_Case_Record_Type_Label_for_Core_Returns';
import canCreateCoreCases from '@salesforce/customPermission/NAC_Create_Core_Return';

const STAGE1LABEL = 'Record Type';
const STAGE2LABEL = 'Case Details';
const STAGE3LABEL = 'Add Line Items';
const STAGE3NEWSHIPPINGADDRESSLABEL = 'New Shipping Address';
const STAGE3UPDATESHIPPINGADDRESSLABEL = 'Update Shipping Address';
const STAGE3UPDATEBILLINGADDRESSLABEL = 'Update Billing Address';
const STAGE1NEXTBUTTONLABEL = Continue;
const STAGE2NEXTBUTTONLABEL = Continue;
const STAGE3NEXTBUTTONLABEL = 'Submit';

const DELAY = 500;

export default class Nac_CreateCaseComponent extends NavigationMixin(LightningElement) {

    label = {
        okLabel,
        cancelLabel,
        performancePartLabel,
        coreReturnLabel
    }
    //CXREF-4176--->
    isAddressChange = false;
    newShippingAddress = false;
    updateShippingAddress = false;
    updateBillingAddress = false;
    noAddressOption = false;
    contactPointAddressId = '';
    //--->CXREF-4176
    objectApiName = 'Case';
    showSpinner = false;
    @track stages = [STAGE1LABEL, STAGE2LABEL, STAGE3LABEL];
    currentStage = STAGE1LABEL;
    step1 = true;
    step2 = false;
    step3 = false;
    showBackButton = false;
    showRecordEditFormButton = false;
    nextButtonLabel = STAGE1NEXTBUTTONLABEL;
    recordTypeId;
    sectionList;
    ppSectionList;
    activeSections = [];
    ppActiveSections = [];
    recordTypeOptions = [];
    disableClearSelectedButton = true;
    perfPartdisableClearSelectedButton = true;
    showModal = false;
    disableSelectbutton = true;
    ppdisableSelectbutton = true;
    coreReturnProductList = [];
    perfPartReturnProductList = [];
    coreReturnLocation = '';
    selectedRecord;
    ppselectedRecord;
    additionalCondition = '';
    headerCheckBox = false;
    perfPartheaderCheckBox = false;
    disableNextButton = true;
    caseFields;
    listViewId = 'Recent';
    addMoreItemLabel = 'Add Items';
    perfPartaddMoreItemLabel = 'Add Items';
    isCoreReturn = false;
    isPerformancePart = false;
    coreReturnId;
    performancePartId;
    @track isFieldEditableForLoc = true;

    lcoreLoc;

    @track caseType;
    @track caseReson;
    @track subject;
    @track coreLocation;
    //CXREF-4176--->
    @track shippingAddressOptions = [];
    @track billingAddressOptions = [];
    @track addressOptions = [];
    @track address = {
        street: '',
        city: '',
        zipCode: '',
        state: '',
        country: ''
    }
    //--->CXREF-4176

    classMap = {
        size1: "slds-col slds-p-around_xx-small slds-size_1-of-12",
        size2: "slds-col slds-p-around_xx-small slds-size_2-of-12",
        size3: "slds-grid slds-p-around_xx-small slds-size_1-of-12"
    }

    get columnHeader() {
        return [
            { label: "Core Item P/N", class: this.classMap.size2, showCheckbox: true },
            { label: "Product Name", class: this.classMap.size2, showCheckbox: false },
            { label: "QTY", class: this.classMap.size1, showCheckbox: false },
            { label: "Warranty", class: this.classMap.size1, showCheckbox: false },
            { label: "Serial #", class: this.classMap.size1, showCheckbox: false },
            { label: "Warranty #", class: this.classMap.size2, showCheckbox: false },
            { label: "MPR Tag #", class: this.classMap.size2, showCheckbox: false },
            { label: "Actions", class: this.classMap.size1, showCheckbox: false },
        ];
    }

    get columnHeaderPerformance() {
        return [
            { label: "Carrier Order#", class: this.classMap.size1, showCheckbox: true, showToolTip: true },
            { label: "PO#", class: this.classMap.size1, showCheckbox: false, showToolTip: true },
            { label: "Part #", class: this.classMap.size1, showCheckbox: false, showToolTip: true },
            { label: "Part # (Not tied to Order)", class: this.classMap.size1, showCheckbox: false, showToolTip: false },
            { label: "Shipment #", class: this.classMap.size1, showCheckbox: false, showToolTip: false },
            { label: "Line", class: this.classMap.size1, showCheckbox: false, showToolTip: false },
            { label: "Disputed Quantity #", class: this.classMap.size1, showCheckbox: false, showToolTip: true },
            { label: "Model/Serial #", class: this.classMap.size2, showCheckbox: false, showToolTip: false },
            { label: "Additional Detail/Customer Comments", class: this.classMap.size2, showCheckbox: false, showToolTip: true },
            { label: "Action", class: this.classMap.size1, showCheckbox: false, showToolTip: false },
        ];
    }

    warrantyValue = 'No';

    @wire(getObjectInfo, { objectApiName: RETURNITEM_OBJECT })
    returnItemObjectInfo

    @wire(getPicklistValues, {
        recordTypeId: "$returnItemObjectInfo.data.defaultRecordTypeId",
        fieldApiName: IS_WARRANTY_FIELD
    })
    warrantyOptions;


    @wire(getObjectInfo, { objectApiName: CASELINEITEM_OBJECT })
    caseLineItemObjectInfo

    @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
    caseObjectInfo({ data, error }) {
        if (data) {
            let optionsValues = [];
            const rtInfos = data.recordTypeInfos;
            let rtValues = Object.values(rtInfos);
            rtValues.forEach(rt => {
                if (rt.name == 'NAOCAP Aftermarket Part') {
                    optionsValues.push({
                        label: this.label.performancePartLabel,
                        value: rt.recordTypeId
                    })
                    this.coreReturnId = rt.recordTypeId;
                }
                if (rt.name == 'NAOCAP Core Return' && canCreateCoreCases) {
                    optionsValues.push({
                        label: this.label.coreReturnLabel,
                        value: rt.recordTypeId
                    })
                    this.performancePartId = rt.recordTypeId;
                }

            })
            this.recordTypeOptions = optionsValues;
        }
        else if (error) {
            console.log('Error' + JSON.stringify(error));
        }
    }

    @wire(getListUi, { objectApiName: CASE_OBJECT })
    caseListView({ data, error }) {
        if (data) {
            data.lists.forEach(list => {
                if (list.apiName == 'NAC_Core_Returns') {
                    this.listViewId = list.id;
                }
            })
        }
        else if (error) {
            console.log('Error' + JSON.stringify(error));
        }
    }

    connectedCallback() {
        this.showSpinner = true;
        //CXREF-4176--->
        getCaseDetails({ objectName: this.objectApiName })
            .then(result => {
                this.showSpinner = false;
                try {
                    this.sectionList = this.sortByKey(result.coreFields, 'order');
                    this.sectionList.forEach(section => this.activeSections.push(section.sectionAPIName));
                    this.ppSectionList = this.sortByKey(result.performancePartsFields, 'order');
                    this.ppSectionList.forEach(section => this.ppActiveSections.push(section.sectionAPIName));
                    result.addressList.forEach(data => {
                        let address = '';
                        if (data.Street) address += data.Street;
                        if (data.City) address += ' ' + data.City;
                        if (data.State) address += ' ' + data.State;
                        if (data.PostalCode) address += ' ' + data.PostalCode;
                        if (data.Country) address += ' ' + data.Country;
                        let addressData = {
                            selected: false,
                            label: address,
                            value: data.Id,
                            street: data.Street,
                            city: data.City,
                            state: data.State,
                            postalCode: data.PostalCode,
                            country: data.Country
                        };
                        if (data.AddressType == 'Billing') {
                            this.billingAddressOptions.push(addressData);
                        } else if (data.AddressType == 'Shipping') {
                            this.shippingAddressOptions.push(addressData);
                        }
                    });
                }
                catch (error) {
                    console.log(JSON.stringify(error.message));
                }
            })
            .catch(error => {
                this.showSpinner = false;
                console.log('Error' + JSON.stringify(error));
            });
        //--->CXREF-4176
    }

    sortByKey(array, key) {
        return array.sort(function (a, b) {
            var x = a[key]; var y = b[key];
            return ((x < y) ? -1 : ((x > y) ? 1 : 0));
        });
    }

    handleClickNext() {
        switch (this.currentStage) {
            case STAGE1LABEL:
                this.currentStage = STAGE2LABEL;
                this.nextButtonLabel = STAGE2NEXTBUTTONLABEL;
                this.disableNextButton = true;
                this.showBackButton = false;
                this.step1 = false;
                this.step2 = true;
                this.step3 = false;
                this.showRecordEditFormButton = true;
                let recordTypeId = this.recordTypeId;
                this.recordTypeId = '';
                this.recordTypeId = recordTypeId;
                this.showSpinner = true;
                break;
            case STAGE2LABEL:
                this.currentStage = STAGE3LABEL;
                this.nextButtonLabel = STAGE3NEXTBUTTONLABEL;
                this.disableNextButton = true;
                this.showBackButton = true;
                this.step1 = false;
                this.step2 = false;
                this.step3 = true;
                this.showRecordEditFormButton = false;
                this.validateAddressData();
                if (this.coreReturnProductList.length > 0) {
                    setTimeout(() => {
                        this.validateData();
                    }, 100);
                }
                break;
            case STAGE3LABEL:
                this.handleClickNextStage3();
                break;
            case STAGE3NEWSHIPPINGADDRESSLABEL:
                this.handleClickNextStage3();
                break;
            case STAGE3UPDATESHIPPINGADDRESSLABEL:
                this.handleClickNextStage3();
                break;
            case STAGE3UPDATEBILLINGADDRESSLABEL:
                this.handleClickNextStage3();
                break;
            default:
                this.currentStage = STAGE1LABEL;
                this.nextButtonLabel = STAGE1NEXTBUTTONLABEL;
                this.showBackButton = false;
                this.step1 = true;
                this.step2 = false;
                this.step3 = false;
                this.showRecordEditFormButton = false;
        }
    }

    handleClickNextStage3() {
        if (this.isCoreReturn) {
            this.submitCase();
        } else if (this.isPerformancePart) {
            this.perfPartSubmitCase();
        }
    }

    handleClickBack() {
        switch (this.currentStage) {
            case STAGE3LABEL:
                this.handleClickBackStage3();
                break;
            case STAGE3NEWSHIPPINGADDRESSLABEL:
                this.handleClickBackStage3();
                break;
            case STAGE3UPDATESHIPPINGADDRESSLABEL:
                this.handleClickBackStage3();
                break;
            case STAGE3UPDATEBILLINGADDRESSLABEL:
                this.handleClickBackStage3();
                break;
            default:
                this.currentStage = STAGE1LABEL;
                this.nextButtonLabel = STAGE1NEXTBUTTONLABEL;
                this.showBackButton = true;
                this.step1 = true;
                this.step2 = false;
                this.step3 = false;
                this.showRecordEditFormButton = false;
        }
    }

    handleClickBackStage3() {
        this.currentStage = STAGE2LABEL;
        this.nextButtonLabel = STAGE2NEXTBUTTONLABEL;
        this.showBackButton = false;
        this.step1 = false;
        this.step2 = true;
        this.step3 = false;
        this.showRecordEditFormButton = true;
    }

    handleRecordTypeSelect(event) {
        this.recordTypeId = event.detail.value;
        this.disableNextButton = false;
        this.recordTypeOptions.forEach(rt => {
            if (rt.label == this.label.performancePartLabel && rt.value == this.recordTypeId) {
                this.isCoreReturn = false;
                this.isPerformancePart = true;
            }
            if (rt.label == this.label.coreReturnLabel && rt.value == this.recordTypeId) {
                this.isCoreReturn = true;
                this.isPerformancePart = false;
            }
        })

    }

    handleLoad() {
        window.clearTimeout(this.delayTimeout);
        this.delayTimeout = setTimeout(() => {
            this.showSpinner = false;
        }, DELAY);
    }

    handleCaseFieldChange(event) {
        if (event.currentTarget.dataset.fieldname == 'NATT_Core_Return_Location__c') {
            this.coreLocation = event.detail.value;
            //this.lcoreLoc=this.coreLocation;
            this.isFieldEditableForLoc = this.locationCheck();
            console.log('core location is '+this.lcoreLoc);
            console.log('This Field location check is '+this.isFieldEditableForLoc);
        }
        if (event.currentTarget.dataset.fieldname == 'NATT_Core_Return_Location__c' && this.coreReturnProductList.length > 0 && this.coreReturnLocation != event.detail.value) {
            const evt = new ShowToastEvent({
                title: 'Warning',
                message: 'Changing the Core Return Location will remove all the products selected earlier!',
                variant: 'warning',
                mode: 'dismissable'
            });
            this.dispatchEvent(evt);
        }
        if (event.currentTarget.dataset.fieldname == 'Type') {
            this.caseType = event.detail.value;
            if (this.caseType && this.caseReson) {
                this.subject = this.caseType + " - " + this.caseReson;
                this.template.querySelector('[data-fieldname="Subject"]').value = this.subject;
            }
            if (!this.caseType || !this.caseReson) {
                this.subject = '';
                this.template.querySelector('[data-fieldname="Subject"]').value = this.subject;
            }
            this.sectionList.forEach(section => {
                section.fieldList.forEach(field => {
                    if (field.apiName == 'Type') {
                        field.value = this.subject;
                    }
                })
            });
        }
        if (event.currentTarget.dataset.fieldname == 'NATT_Case_Reason__c') {
            this.caseReson = event.detail.value;
            if (this.caseType && this.caseReson) {
                this.subject = this.caseType + " - " + this.caseReson;
                this.template.querySelector('[data-fieldname="Subject"]').value = this.subject;
            }
            if (!this.caseType || !this.caseReson) {
                this.subject = '';
                this.template.querySelector('[data-fieldname="Subject"]').value = this.subject;
            }
            this.sectionList.forEach(section => {
                section.fieldList.forEach(field => {
                    if (field.apiName == 'NATT_Case_Reason__c') {
                        field.value = this.subject;
                    }
                })
            });
        }
    }

    pphandleCaseFieldChange(event) {
        if (event.currentTarget.dataset.fieldname == 'Type') {
            this.caseType = event.detail.value;
            //CXREF-4176--->
            if (this.caseType == 'New/Change Address') {
                this.isAddressChange = true;
            } else {
                this.isAddressChange = false;
                this.newShippingAddress = false;
                this.updateShippingAddress = false;
                this.updateBillingAddress = false;
            }
            //--->CXREF-4176
            if (this.caseType && this.caseReson) {
                this.subject = this.caseType + " - " + this.caseReson;
                this.template.querySelector('[data-fieldname="Subject"]').value = this.subject;
            }
            if (!this.caseType || !this.caseReson) {
                this.subject = '';
                this.template.querySelector('[data-fieldname="Subject"]').value = this.subject;
            }
            this.sectionList.forEach(section => {
                section.fieldList.forEach(field => {
                    if (field.apiName == 'Type') {
                        field.value = this.subject;
                    }
                })
            });
        }
        if (event.currentTarget.dataset.fieldname == 'NATT_Case_Reason__c') {
            this.caseReson = event.detail.value;
            //CXREF-4176--->
            if (this.isAddressChange) {
                this.addressOptions = [];
                this.address.street = '';
                this.address.city = '';
                this.address.zipCode = '';
                this.address.state = '';
                this.address.country = '';
                switch (this.caseReson) {
                    case 'New shipping address':
                        this.newShippingAddress = true;
                        this.updateShippingAddress = false;
                        this.updateBillingAddress = false;
                        this.stages = [STAGE1LABEL, STAGE2LABEL, STAGE3NEWSHIPPINGADDRESSLABEL];
                        break;
                    case 'Change existing shipping address':
                        this.newShippingAddress = false;
                        this.updateShippingAddress = true;
                        this.updateBillingAddress = false;
                        this.validateAddressOptions(this.shippingAddressOptions);
                        this.stages = [STAGE1LABEL, STAGE2LABEL, STAGE3UPDATESHIPPINGADDRESSLABEL];
                        break;
                    case 'Change existing billing address':
                        this.newShippingAddress = false;
                        this.updateShippingAddress = false;
                        this.updateBillingAddress = true;
                        this.validateAddressOptions(this.billingAddressOptions);
                        this.stages = [STAGE1LABEL, STAGE2LABEL, STAGE3UPDATEBILLINGADDRESSLABEL];
                        break;
                    default:
                        this.newShippingAddress = false;
                        this.updateShippingAddress = false;
                        this.updateBillingAddress = false;
                        this.stages = [STAGE1LABEL, STAGE2LABEL, STAGE3LABEL];
                }
            } else {
                this.stages = [STAGE1LABEL, STAGE2LABEL, STAGE3LABEL];
            }
            //--->CXREF-4176
            if (this.caseType && this.caseReson) {
                this.subject = this.caseType + " - " + this.caseReson;
                this.template.querySelector('[data-fieldname="Subject"]').value = this.subject;
            }
            if (!this.caseType || !this.caseReson) {
                this.subject = '';
                this.template.querySelector('[data-fieldname="Subject"]').value = this.subject;
            }
            this.sectionList.forEach(section => {
                section.fieldList.forEach(field => {
                    if (field.apiName == 'NATT_Case_Reason__c') {
                        field.value = this.subject;
                    }
                })
            });
        }
        if (event.currentTarget.dataset.fieldname == 'Subject') {
            this.subject = event.detail.value;
        }
    }

    validateAddressOptions(options) {
        if (options) {
            if (options.length > 0) {
                this.noAddressOption = false;
                this.addressOptions = JSON.parse(JSON.stringify(options));
                if (options.length == 1) {
                    this.addressOptions.forEach(data => {
                        data.selected = true;
                        this.address.street = data.street;
                        this.address.city = data.city;
                        this.address.zipCode = data.postalCode;
                        this.address.state = data.state;
                        this.address.country = data.country;
                        this.contactPointAddressId = data.value;
                    });
                }
            } else {
                this.noAddressOption = true;
            }
        } else {
            this.noAddressOption = true;
        }
    }

    handleAddressSelect(event) {
        this.addressOptions.forEach(data => {
            if (data.value == event.target.value) {
                data.selected = true;
                this.address.street = data.street;
                this.address.city = data.city;
                this.address.zipCode = data.postalCode;
                this.address.state = data.state;
                this.address.country = data.country;
                this.contactPointAddressId = data.value;
            } else {
                data.selected = false;
            }
        });
        this.validateAddressData();
    }

    handleCaseAddressFieldChange(event) {
        switch (event.currentTarget.dataset.fieldname) {
            case 'NAOCAP_Street__c':
                this.address.street = event.detail.value;
                break;
            case 'NAOCAP_City__c':
                this.address.city = event.detail.value;
                break;
            case 'NAOCAP_Zip_Code__c':
                this.address.zipCode = event.detail.value;
                break;
            case 'NAOCAP_State__c':
                this.address.state = event.detail.value;
                break;
            case 'NAOCAP_Country__c':
                this.address.country = event.detail.value;
                break;
        }
        this.validateAddressData();
    }

    validateAddressData() {
        if (this.isAddressChange) {
            if (this.newShippingAddress) {
                this.currentStage = STAGE3NEWSHIPPINGADDRESSLABEL;
                if (this.address.street && this.address.city && this.address.zipCode && this.address.state && this.address.country) {
                    this.disableNextButton = false;
                } else {
                    this.disableNextButton = true;
                }
            } else {
                if (this.updateShippingAddress) {
                    this.currentStage = STAGE3UPDATESHIPPINGADDRESSLABEL;
                } else if (this.updateBillingAddress) {
                    this.currentStage = STAGE3UPDATEBILLINGADDRESSLABEL;
                }
                this.addressOptions.forEach(data => {
                    if (data.value == this.contactPointAddressId) {
                        if (this.address.street && this.address.city && this.address.zipCode && this.address.state && this.address.country && (!this.compareText(this.address.street, data.street) || !this.compareText(this.address.city, data.city) || !this.compareText(this.address.zipCode, data.postalCode) || !this.compareText(this.address.state, data.state) || !this.compareText(this.address.country, data.country))) {
                            this.disableNextButton = false;
                        } else {
                            this.disableNextButton = true;
                        }
                    }
                });
            }
        }
    }

    compareText(a, b) {
        return (a && b && a.replace(/\s+/g, '').toLowerCase() == b.replace(/\s+/g, '').toLowerCase()) ? true : false;
    }

    handleSubmit(event) {
        event.preventDefault();
        if (this.isCoreReturn) {
            this.caseFields = JSON.parse(JSON.stringify(event.detail.fields));
            this.sectionList.forEach(section => {
                section.fieldList.forEach(field => {
                    if (this.caseFields.hasOwnProperty(field.apiName)) {
                        field.value = this.caseFields[field.apiName];
                        if (field.apiName == 'Subject') {
                            field.value = this.subject;
                        }
                    }
                })
            });
            if (this.coreReturnLocation != this.caseFields.NATT_Core_Return_Location__c) {
                this.coreReturnProductList = [];
                this.addMoreItemLabel = 'Add Items';
            }
            this.coreReturnLocation = this.caseFields.NATT_Core_Return_Location__c;
            this.formQueryCondition();
            this.handleClickNext();
        } else if (this.isPerformancePart) {
            this.caseFields = JSON.parse(JSON.stringify(event.detail.fields));
            this.ppSectionList.forEach(section => {
                section.fieldList.forEach(field => {
                    if (this.caseFields.hasOwnProperty(field.apiName)) {
                        field.value = this.caseFields[field.apiName];
                        if (field.apiName == 'Subject') {
                            field.value = this.subject;
                        }
                    }
                })
            });
            this.handleClickNext();
        }
    }

    formQueryCondition() {
        if (this.coreReturnLocation) {
            this.additionalCondition = " AND NATT_Core_Return_Location__c = '" + this.coreReturnLocation + "'";
            if (this.coreReturnProductList.length > 0) {
                this.additionalCondition += " AND ID NOT in (";
                this.coreReturnProductList.forEach(value => this.additionalCondition += "'" + value.Id + "',");
                this.additionalCondition = this.additionalCondition.slice(0, -1) + ")";
            }
        }
    }

    handleClickCancel() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Case',
                actionName: 'list'
            },
            state: {
                filterName: this.listViewId
            },
        });
    }
    

    validateSerialNumber(ReturnItems){
        let serialNumberExist =true;
        let lcoreLoc = this.coreLocation;
        let islocTypeContains = false; 
        if (lcoreLoc == 'Carrier/Carlyle Compressor Core Returns' || lcoreLoc == 'Carrier Transicold Electronics' ||
                  lcoreLoc == 'Return to Panama parts depot' || lcoreLoc == 'Return to Chile parts depot'){
                    islocTypeContains = true;
                  }
        if(! (ReturnItems && ReturnItems.length > 0)){
                return serialNumberExist;
        }
            ReturnItems.forEach(item => {
                if (islocTypeContains && ! item.NATT_Serial__c ){
                    serialNumberExist = false;
                    return serialNumberExist;
                } 
              });
              return serialNumberExist
        
    }
    showToast(title,errormMessage, type,mode){
        //Varient- type:[Error, warning,info]
       // mode= 'dismissable'; 
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: errormMessage,
                variant: type,
                mode: mode
            })
        );
    }


    submitCase() {
        let returnItemFieldList = [];
        let isValid = true;
    
        this.coreReturnProductList.forEach(prod => {
            let returnItemField = {};
            returnItemField.NATT_Product__c = prod.Id;
    
            let isWarranty = false;
    
            prod.value.forEach(field => {
                if (field.isEditable) {
                    returnItemField[field.label] = field.value;
                }
    
                if (field.label === 'NAC_Is_Warranty__c' && field.value === 'Yes') {
                    isWarranty = true;
                }
            });
    
            if (isWarranty) {
                prod.value.forEach(field => {
                    if ((field.label === 'NATT_Warranty__c' || field.label === 'NATT_MPR_Tag__c') && !field.value.trim()) {
                        isValid = false;
                        this.template.querySelector(`[data-id="${prod.Id}"][data-fieldname="${field.label}"]`).classList.add('slds-has-error');
                    } else if ((field.label === 'NATT_Warranty__c' || field.label === 'NATT_MPR_Tag__c') && field.value.trim()) {
                        this.template.querySelector(`[data-id="${prod.Id}"][data-fieldname="${field.label}"]`).classList.remove('slds-has-error');
                    }
                });
            }
    
            returnItemFieldList.push(returnItemField);
        });
    
        if (!isValid) {
            this.showToast('Error', 'Please Populate all required fields (Warranty # and MPR Tag #)', 'error', 'dismissable');
            return;
        }
    
        let isSerialNumberExist = this.validateSerialNumber(returnItemFieldList);
        if (!isSerialNumberExist) {
            this.showToast('Error', 'Serial Number Is Required For This Location', 'error', 'dismissable');
            return;
        }
    
        this.caseFields.RecordTypeId = this.recordTypeId;
        this.showSpinner = true;
        createCoreReturns({ caseField: this.caseFields, returnItemFields: returnItemFieldList })
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
                        this[NavigationMixin.Navigate]({
                            type: 'standard__webPage',
                            attributes: {
                                url: '/detail/' + result.caseId
                            }
                        });
                    }
                } catch (error) {
                    console.log(JSON.stringify(error.message));
                }
            })
            .catch(error => {
                this.showSpinner = false;
                console.log('Error' + JSON.stringify(error));
            });
    }
    

    perfPartSubmitCase() {
        let returnItemFieldList = [];
        this.perfPartReturnProductList.forEach(prod => {
            let returnItemField = {};
            prod.value.forEach(field => {
                if (field.isEditable) {
                    returnItemField[field.label] = field.value;
                }
            })
            returnItemFieldList.push(returnItemField);
        });
        this.caseFields.RecordTypeId = this.recordTypeId;
        if (this.isAddressChange) {
            this.caseFields.NAOCAP_Street__c = this.address.street;
            this.caseFields.NAOCAP_City__c = this.address.city;
            this.caseFields.NAOCAP_Zip_Code__c = this.address.zipCode;
            this.caseFields.NAOCAP_State__c = this.address.state;
            this.caseFields.NAOCAP_Country__c = this.address.country;
            if (this.contactPointAddressId && !this.newShippingAddress) {
                this.caseFields.NAOCAP_Contact_Point_Address__c = this.contactPointAddressId;
            }
        }
        this.showSpinner = true;
        createPerfPartReturns({ caseField: this.caseFields, returnItemFields: returnItemFieldList })
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
                        this[NavigationMixin.Navigate]({
                            type: 'standard__webPage',
                            attributes: {
                                url: '/detail/' + result.caseId
                            }
                        });
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
    }

    handleAddMoreItems() {
        this.showModal = true;
        this.disableSelectbutton = true;
        this.selectedRecord = null;
    }


    pphandleAddMoreItems() {
        try {
            this.showSpinner = true;
            this.perfPartReturnProductList.push({
                Id: '',
                recordDetails: '',
                checkbox: false,
                value: [
                    { label: 'NATT_JDE_SO__c', value: '', isEditable: true, type: 'text', isCombobox: false, isdelete: false, class: this.classMap.size3, showCheckbox: true, required: true, maxlength: this.caseLineItemObjectInfo.data.fields.NATT_JDE_SO__c.length },
                    { label: 'NAC_Purchase_Order_Number__c', value: '', isEditable: true, type: 'text', isCombobox: false, isdelete: false, class: this.classMap.size1, showCheckbox: false, required: true, maxlength: this.caseLineItemObjectInfo.data.fields.NAC_Purchase_Order_Number__c.length },
                    { label: 'NATT_Part__c', value: '', isEditable: true, type: 'text', isCombobox: false, isdelete: false, class: this.classMap.size1, showCheckbox: false, required: true, maxlength: this.caseLineItemObjectInfo.data.fields.NATT_Part__c.length },
                    { label: 'NAC_Part_Not_tied_to_Order__c', value: '', isEditable: true, type: 'text', isCombobox: false, isdelete: false, class: this.classMap.size1, showCheckbox: false, required: false, maxlength: this.caseLineItemObjectInfo.data.fields.NAC_Part_Not_tied_to_Order__c.length },
                    { label: 'NATT_Packing_Slip_Number__c', value: '', isEditable: true, type: 'text', isCombobox: false, isdelete: false, class: this.classMap.size1, showCheckbox: false, required: false, maxlength: this.caseLineItemObjectInfo.data.fields.NATT_Packing_Slip_Number__c.length },
                    { label: 'NAC_Line_Number__c', value: '', isEditable: true, type: 'text', isCombobox: false, isdelete: false, class: this.classMap.size1, showCheckbox: false, required: false, maxlength: this.caseLineItemObjectInfo.data.fields.NAC_Line_Number__c.length },
                    { label: 'NATT_Disputed_Quantity__c', value: 0, isEditable: true, type: 'number', isCombobox: false, isdelete: false, class: this.classMap.size1, showCheckbox: false, required: true, maxlength: this.caseLineItemObjectInfo.data.fields.NATT_Disputed_Quantity__c.length },
                    { label: 'NATT_Serial_Number__c', value: '', isEditable: true, type: 'text', isCombobox: false, isdelete: false, class: this.classMap.size2, showCheckbox: false, required: false, maxlength: this.caseLineItemObjectInfo.data.fields.NATT_Serial_Number__c.length },
                    { label: 'NATT_Additional_Detail__c', value: '', isEditable: true, type: 'text', isCombobox: false, isdelete: false, class: this.classMap.size2, showCheckbox: false, required: true },
                    { label: 'deleteIcon', isEditable: false, type: 'icon', isdelete: true, isCombobox: false, class: this.classMap.size1, showCheckbox: false, required: false },
                ],
            });
            for (let i = 0; i < this.perfPartReturnProductList.length; i++) {
                this.perfPartReturnProductList[i].Id = i;
            }
            this.perfPartaddMoreItemLabel = 'Add More Items';
            this.showSpinner = false;
            this.disableNextButton = true;
        } catch (Ex) {
            console.log(Ex);
        }
    }

    handleCancel() {
        this.showModal = false;
        this.disableSelectbutton = true;
        this.selectedRecord = null;
    }
    locationCheck(){
        console.log(' this.coreLocation-'+ this.coreLocation);
        this.lcoreLoc= this.coreLocation;
        var  editable = true;
        console.log(this.isFieldEditableForLoc);
        if(this.lcoreLoc == 'Carrier/Carlyle Compressor Core Returns'){
            editable = false;
        }
        else if(this.lcoreLoc == 'Carrier Transicold Electronics'){
            editable = false;
        }
        else if(this.lcoreLoc == 'Return to Panama parts depot'){
            editable = false;
        }
        else if(this.lcoreLoc == 'Return to Chile parts depot'){
            editable = false;
        }
        console.log('editable'+editable);
        return editable;
    }

    handleSelectCoreItem() {
        this.coreReturnProductList.push({
            Id: this.selectedRecord.Id,
            recordDetails: this.selectedRecord,
            checkbox: false,
            value: [
                { label: 'name', value: this.selectedRecord.ProductCode, isEditable: false, type: 'text', isCombobox: false, isdelete: false, class: this.classMap.size2, showCheckbox: true, required: false },
                { label: 'productName', value: this.selectedRecord.Name, isEditable: false, type: 'text', isCombobox: false, isdelete: false, class: this.classMap.size2, showCheckbox: false, required: false },
                { label: 'NATT_Quantity__c', value: 1, isEditable:this.isFieldEditableForLoc, type: 'number', isCombobox: false, isdelete: false, class: this.classMap.size1, showCheckbox: false, required: true, maxlength: this.returnItemObjectInfo.data.fields.NATT_Quantity__c.length },
                { label: 'NAC_Is_Warranty__c', value: 'No', isEditable: true, type: 'combobox', isCombobox: true, isdelete: false, class: this.classMap.size1, showCheckbox: false, required: false },
                { label: 'NATT_Serial__c', value: '', isEditable: true, type: 'text', isCombobox: false, isdelete: false, class: this.classMap.size1, showCheckbox: false, required: false, maxlength: this.returnItemObjectInfo.data.fields.NATT_Serial__c.length },
                { label: 'NATT_Warranty__c', value: '', isEditable: true, type: 'text', isCombobox: false, isdelete: false, class: this.classMap.size2, showCheckbox: false, required: false, maxlength: this.returnItemObjectInfo.data.fields.NATT_Warranty__c.length },
                { label: 'NATT_MPR_Tag__c', value: '', isEditable: true, type: 'text', isCombobox: false, isdelete: false, class: this.classMap.size2, showCheckbox: false, required: false, maxlength: this.returnItemObjectInfo.data.fields.NATT_MPR_Tag__c.length },
                { label: 'deleteIcon', isEditable: false, type: 'icon', isdelete: true, isCombobox: false, class: this.classMap.size1, showCheckbox: false, required: false },
            ],
        });
        this.addMoreItemLabel = 'Add More Items';
        this.showModal = false;
        this.disableSelectbutton = true;
        this.selectedRecord = null;
        this.formQueryCondition();
        setTimeout(() => {
            this.validateData();
        }, 100);

    }

  
    handleIsWarrantyChange(event) {
        try {
            this.disableNextButton = false;
    
            let warrantyValue = event.target.value; // Get the warranty value
            let index = parseInt(event.currentTarget.dataset.index);
    
            this.coreReturnProductList.forEach((prod, prodIndex) => {
                if (prodIndex === index) { 
                    prod.value.forEach(field => {
                        if (field.label === 'NAC_Is_Warranty__c') {
                            field.value = warrantyValue;
                        }
                    });
    
                    if (warrantyValue === 'Yes') {
                        prod.value.forEach(field => {
                            if (((field.label === 'NATT_Warranty__c' || field.label === 'NATT_MPR_Tag__c' )) && !field.value.trim()) {
                                // Set field as required and show error if empty
                                field.required = true;
                                if (!field.value) {
                                    this.template.querySelector(`[data-id="${prod.Id}"][data-index="${index}"][data-fieldname="${field.label}"]`).classList.add('slds-has-error');
                                    this.disableNextButton = true;
                                } else {
                                    this.template.querySelector(`[data-id="${prod.Id}"][data-index="${index}"][data-fieldname="${field.label}"]`).classList.remove('slds-has-error');
                                }
                            }
                        });
                    } else if (warrantyValue === 'No') {
                        prod.value.forEach(field => {
                            if (field.label === 'NATT_Warranty__c' || field.label === 'NATT_MPR_Tag__c') {
                                field.required = false;
                                // Remove error highlighting
                                this.template.querySelector(`[data-id="${prod.Id}"][data-index="${index}"][data-fieldname="${field.label}"]`).classList.remove('slds-has-error');
                            }
                        });
                    }
                }
            });
        } catch (ex) {
            console.error(ex);
        }
    }

 

    validateData() {
        this.disableNextButton = false;
        this.coreReturnProductList.forEach(prod => {
            prod.value.forEach(field => {
                if (field.required) {
                    if (field.value == '' || (field.label == 'NATT_Quantity__c' && field.value < 1)) {
                        this.template.querySelector('[data-id="' + prod.Id + '"][data-fieldname="' + field.label + '"]').classList.add('slds-has-error');
                        this.disableNextButton = true;
                    } else {
                        this.template.querySelector('[data-id="' + prod.Id + '"][data-fieldname="' + field.label + '"]').classList.remove('slds-has-error');
                    }
                }
            })
        });
    }

    handleFieldChange(event) {

        let index = parseInt(event.target.dataset.index);

        let id = event.currentTarget.dataset.id;

        let fieldName = event.currentTarget.dataset.fieldname;

        let value = event.currentTarget.value;

        this.disableNextButton = false;

        this.coreReturnProductList.forEach((prod, prodIndex) => {

            if (prod.Id === id && prodIndex === index) {

                let updatedProd = JSON.parse(JSON.stringify(prod));

                updatedProd.value.forEach(field => {

                    if (field.label === fieldName) {

                        field.value = value;

                        console.log('field.value => ' + field.value);

                    }

                    if (field.required && this.isFieldEditableForLoc === true) {

                        if (field.value === '' || (field.label === 'NATT_Quantity__c' && field.value < 1)) {

                            this.template.querySelector(`[data-id="${id}"][data-index="${index}"][data-fieldname="${field.label}"]`).classList.add('slds-has-error');

                            this.disableNextButton = true;

                        } else {

                            this.template.querySelector(`[data-id="${id}"][data-index="${index}"][data-fieldname="${field.label}"]`).classList.remove('slds-has-error');

                        }

                    }

                });

            
                this.coreReturnProductList[prodIndex] = updatedProd;

            }

        });
    }

    pphandleFieldChange(event) {
        this.disableNextButton = false;
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
                    this.disableNextButton = true;
                } else if (field.value != '' && (field.label == 'NATT_JDE_SO__c' || field.label == 'NAC_Purchase_Order_Number__c' || field.label == 'NATT_Part__c' || field.label == 'NATT_Disputed_Quantity__c' || field.label == 'NATT_Additional_Detail__c')) {
                    this.template.querySelector('[data-id="' + prod.Id + '"][data-fieldname="' + field.label + '"]').classList.remove('slds-has-error');
                }
            })
            //CXREF- 4009 Changes Ends
        });


    }

    deleteRow(event) {
        try {
            let index = parseInt(event.currentTarget.dataset.index);
            
            let newList = this.coreReturnProductList.filter((prod, i) => i !== index);
            this.coreReturnProductList = newList;
    
            this.addMoreItemLabel = this.coreReturnProductList.length > 0 ? 'Add More Items' : 'Add Items';
    
            // Update the form query condition
            this.formQueryCondition();
        } catch (ex) {
            console.log(ex);
        }
    }
    

    ppdeleteRow(event) {
        let tempList = this.perfPartReturnProductList.filter(prod => prod.Id != event.currentTarget.dataset.id);
        this.perfPartReturnProductList = tempList;
        if (this.perfPartReturnProductList.length > 0) {
            this.perfPartaddMoreItemLabel = 'Add More Items';
        } else {
            this.perfPartaddMoreItemLabel = 'Add Items';
        }
        this.perfPartReturnProductList.forEach(prod => {
            prod.value.forEach(field => {
                if (field.value == '' && (field.label == 'NATT_JDE_SO__c' || field.label == 'NAC_Purchase_Order_Number__c' || field.label == 'NATT_Part__c' || field.label == 'NATT_Disputed_Quantity__c' || field.label == 'NATT_Additional_Detail__c')) {
                    this.template.querySelector('[data-id="' + prod.Id + '"][data-fieldname="' + field.label + '"]').classList.add('slds-has-error');
                    this.disableNextButton = true;
                } else if (field.value != '' && (field.label == 'NATT_JDE_SO__c' || field.label == 'NAC_Purchase_Order_Number__c' || field.label == 'NATT_Part__c' || field.label == 'NATT_Disputed_Quantity__c' || field.label == 'NATT_Additional_Detail__c')) {
                    this.template.querySelector('[data-id="' + prod.Id + '"][data-fieldname="' + field.label + '"]').classList.remove('slds-has-error');
                    this.disableNextButton = false;
                }
            })
        });

        this.ppvalidateData();
    }

    handleLookupSelect(event) {
        this.disableSelectbutton = false;
        this.selectedRecord = event.detail.selectedRecord;
    }

    handleCheckAll(event) {
        this.perfPartheaderCheckBox = event.target.checked;
        this.disableClearSelectedButton = !event.target.checked;
        
        this.coreReturnProductList.forEach(prod => {
            prod.checkbox = event.target.checked; 
            this.template.querySelector('[data-id="' + prod.Id + '"]').checked = prod.checkbox;
        });
    }

    perfPartHandleCheckAll(event) {
        this.headerCheckBox = event.target.checked;
        this.perfPartdisableClearSelectedButton = !event.target.checked;
        this.perfPartReturnProductList.forEach(prod => {
            prod.checkbox = event.target.checked;
            this.template.querySelector('[data-id="' + prod.Id + '"]').checked = prod.checkbox;
        });
    }
   
    handleCheck(event) {
        this.disableClearSelectedButton = true;
        let index = parseInt(event.currentTarget.dataset.index);
        this.headerCheckBox = true;
        
        this.coreReturnProductList.forEach((prod, idx) => {
            if (idx === index) { 
                prod.checkbox = event.target.checked;
            }
            if (prod.checkbox) {
                this.disableClearSelectedButton = false;
            } else {
                this.headerCheckBox = false;
            }
        });
    
        this.template.querySelector('[data-id="headerCheckBox"]').checked = this.headerCheckBox;
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

    handleClearSelected() {
        let tempList = this.coreReturnProductList.filter(prod => !prod.checkbox);
        this.coreReturnProductList = tempList;
        this.addMoreItemLabel = 'Add Items';
        this.headerCheckBox = false;
        this.template.querySelector('[data-id="headerCheckBox"]').checked = this.headerCheckBox;
        this.disableClearSelectedButton = true;
        this.formQueryCondition();
    }
    

    handleClearSelectedPerformancePart() {
        let tempList = this.perfPartReturnProductList.filter(prod => !prod.checkbox);
        this.perfPartReturnProductList = tempList;
        this.perfPartaddMoreItemLabel = 'Add Items';
        this.perfPartheaderCheckBox = false;
        this.template.querySelector('[data-id="ppheaderCheckBox"]').checked = this.perfPartheaderCheckBox;
        this.perfPartdisableClearSelectedButton = true;
    }
}