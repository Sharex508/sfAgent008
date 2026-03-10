import { LightningElement, track, api } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import communityId from '@salesforce/community/Id';
import getTemplateLink from '@salesforce/apex/NAC_BulkUploadController.GetResourceURL';
import readFile from '@salesforce/apex/NAC_BulkUploadController.readUploadedFile';
import deleteContentDocumentFiles from '@salesforce/apex/NAC_BulkUploadController.deleteContentDocumentFiles';
import addItemToCart from '@salesforce/apex/NAC_BulkUploadController.addItemToCart';
import NAC_Lightning_File_Upload from '@salesforce/resourceUrl/NAC_Lightning_File_Upload';
import getCartDetails from '@salesforce/apex/Nac_GetCustomSettingWareHouseData.getCartDetails';
import helpText from '@salesforce/label/c.NAC_Bulk_Upload_Template_Help_Text';
import okLabel from '@salesforce/label/c.nac_OkLabel';
import cancelLabel from '@salesforce/label/c.nac_CancelLabel';
import pleaseConfirm from '@salesforce/label/c.nac_PleaseConfirmLabel';
import canceheader from '@salesforce/label/c.nac_Bulk_Upload_Cancel_Popup_Header';
import cancelContent1 from '@salesforce/label/c.nac_Bulk_Upload_Cancel_Popup_Content_1';
import cancelContent2 from '@salesforce/label/c.nac_Bulk_Upload_Cancel_Popup_Content_2';
import confirmContent1 from '@salesforce/label/c.nac_Bulk_Upload_Confirm_Popup_Content_1';
import confirmContent2 from '@salesforce/label/c.nac_Bulk_Upload_Confirm_Popup_Content_2';
import errorMessage1 from '@salesforce/label/c.nac_Bulk_Upload_Error_Message_More_than_100_products';
import errorMessage2 from '@salesforce/label/c.nac_Bulk_Upload_Error_Message_General';

const staticResourceName = 'NAC_Bulk_Upload_Template';
const paginationNumbers = 5;
const DELAY = 500;
const TOASTDELAY = 300;

export default class Nac_BulkUpload extends NavigationMixin(LightningElement) {

    @api effectiveAccountId;
    @track resultData;
    @track displayResultData;
    contentDocId;
    downloadLink = '';
    showData = false;
    numberofItems;
    showSpinner = true;
    showToast = false;
    cancelPopUp = false;
    confirmPopUp = false;
    pageCount = 1;
    currentPage = 1;
    showPagination = false;
    delayTimeout;
    toastDelayTimeout;
     isShowModal;
    @api ClickedWarehouse;
    @track pageNumberOptions = [];
    @track pageSizeOptions = [
        { value: 10, selected: true },
        { value: 50, selected: false },
        { value: 100, selected: false },
    ];
    @track breadcrumbs = [
        { label: 'Home', name: 'parent', id: 'crumbs1' },
        { label: 'Upload Order', name: 'child', id: 'crumbs2' },
    ];
    breadCrumbsMap = {
        parent: 'Home',
        child: 'Upload_Order__c',
    };

    label = {
        okLabel,
        cancelLabel,
        helpText,
        pleaseConfirm,
        canceheader,
        cancelContent1,
        cancelContent2,
        confirmContent1,
        confirmContent2,
        errorMessage1,
        errorMessage2
    }

    get acceptedFormats() {
        return ['.csv'];
    }

    get resolvedEffectiveAccountId() {
        const effectiveAcocuntId = this.effectiveAccountId || '';
        let resolved = null;

        if (
            effectiveAcocuntId.length > 0 &&
            effectiveAcocuntId !== '000000000000000'
        ) {
            resolved = effectiveAcocuntId;
        }
        return resolved;
    }

    connectedCallback() {
        getTemplateLink({ resourceName: staticResourceName })
            .then(result => {
                try {
                    this.downloadLink = result;
                }
                catch (error) {
                    console.log(JSON.stringify(error.message));
                }
            })
            .catch(error => {
                console.log('Error' + JSON.stringify(error));
            });
        this.isShowModal = true;
        window.addEventListener('beforeunload', this.deleteContentDocs.bind(this));
        Promise.all([
            loadStyle(this, NAC_Lightning_File_Upload),
        ]).then(() => {
            this.showSpinner = false;
        });
        this.showSpinner = true;
        
         
         if(this.ClickedWarehouse){
            getCartDetails({ communityId: communityId, effectiveAccountId: this.effectiveAccountId, activeCartOrId: 'active' })
            .then(result => {
               this.showSpinner = false;
                this.ClickedWarehouse = result;
                if (this.ClickedWarehouse) {
                    this.isShowModal = true;
                } else {
                    this.isShowModal = false;
                }
            })
            .catch(error => {
                this.error = error;
            });
         }
         else{
            this.isShowModal = true;
         }
        
    }

    closeModal() {
        this.isShowModal = false;
         // Added to fix the stamping on this.clickedwarehouse
        getCartDetails({ communityId: communityId, effectiveAccountId: this.effectiveAccountId, activeCartOrId: 'active' })
        .then(result => {
           this.showSpinner = false;
            this.ClickedWarehouse = result;
            if (this.ClickedWarehouse) {
                this.isShowModal = true;
            } else {
                this.isShowModal = false;
            }
        })
        .catch(error => {
            this.error = error;
        });
        
    }

    keepModalOpen() {
       
        this.isShowModal = false;
        getCartDetails({ communityId: communityId, effectiveAccountId: this.effectiveAccountId, activeCartOrId: 'active' })
            .then(result => {
                this.ClickedWarehouse = result;
                if (this.ClickedWarehouse) {
                    this.isShowModal = true;
                } else {
                    this.isShowModal = false;
                }
            })
            .catch(error => {
                this.error = error;
            });
    }

    handleUploadFinished(event) {
        this.showSpinner = true;
        const uploadedFiles = event.detail.files;
        this.contentDocId = uploadedFiles[0].documentId;       
            getCartDetails({ communityId: communityId, effectiveAccountId: this.effectiveAccountId, activeCartOrId: 'active' })
            .then(result => {
             try {
                this.ClickedWarehouse = result;
                if (this.ClickedWarehouse) {                    
                    this.isShowModal = true;
                    this.handleReadFile();
                } else {                    
                    this.isShowModal = false;
                   
                }
            }
            catch (error) {
                this.showSpinner = false;
                console.log(JSON.stringify(error));
            }    
            })
            
            .catch(error => {
                this.showSpinner = false;
                this.error = error;
                console.log(JSON.stringify(error));
            });
        
        
        
    }

    handleReadFile(event){
        
        readFile({ contentDocumentId: this.contentDocId, communityId: communityId, effectiveAccountId: this.resolvedEffectiveAccountId,selectedWarehouse:this.ClickedWarehouse })
            .then(result => {
                try {
                    this.showSpinner = false;
                    this.resultData = result;
                    if (this.resultData.hasError) {
                        const evt = new ShowToastEvent({
                            title: 'Error',
                            message: this.resultData.errorMessage,
                            variant: 'error',
                            mode: 'dismissable'
                        });
                        this.dispatchEvent(evt);
                        this.deleteContentDocs();
                        this.showData = false;
                        this.numberofItems = null;
                    } else {
                        this.numberofItems = this.resultData.prodWrapList.length;
                        if (this.numberofItems > 100) {
                            this.showToast = true;
                            window.clearTimeout(this.toastDelayTimeout);
                            this.toastDelayTimeout = setTimeout(() => {
                                let toast = this.template.querySelector('[data-id="toast"]');
                                if (toast) {
                                    toast.classList.add('visible');
                                } else {
                                    const evt = new ShowToastEvent({
                                        title: 'Error',
                                        message: this.label.errorMessage1,
                                        variant: 'error',
                                        mode: 'dismissable'
                                    });
                                    this.dispatchEvent(evt);
                                }
                                this.deleteContentDocs();
                                this.showData = false;
                                this.numberofItems = null;
                            }, TOASTDELAY);
                        } else {
                            this.showData = true;

                            this.resultData.prodWrapList.forEach(record => {
                                if (record.isSuperseded) {
                                    record.name = record.supersededPrName;
                                }
                            });
                            this.resetPageNumberOptions();
                        }
                    }
                }
                catch (error) {
                    this.showSpinner = false;
                    console.log(JSON.stringify(error.message));
                }
            })
            .catch(error => {
                this.showSpinner = false;
                console.log('Error' + JSON.stringify(error));
            });

    }

    handleAddItemToCart() {
        this.confirmPopUp = true;
    }

    handleAddItemToCartCancel() {
        this.confirmPopUp = false;
    }

    handleAddItemToCartYes() {
        this.confirmPopUp = false;
        this.showSpinner = true;
        addItemToCart({ bulkProdWrapString: JSON.stringify(this.resultData), communityId: communityId, effectiveAccountId: this.resolvedEffectiveAccountId })
            .then(result => {
                this.showSpinner = false;
                if (result.hasError) {
                    const evt = new ShowToastEvent({
                        title: 'Error',
                        message: result.errorMessage,
                        variant: 'error',
                        mode: 'dismissable'
                    });
                    this.dispatchEvent(evt);
                } else {
                    this.dispatchEvent(
                        new CustomEvent('cartchanged', {
                            bubbles: true,
                            composed: true
                        })
                    );
                    this[NavigationMixin.Navigate]({
                        type: 'standard__webPage',
                        attributes: {
                            url: result.path
                        }
                    });
                }

            })
            .catch(error => {
                this.showSpinner = false;
                const evt = new ShowToastEvent({
                    title: 'Error',
                    message: this.label.errorMessage2,
                    variant: 'error',
                    mode: 'dismissable'
                });
                this.dispatchEvent(evt);
                console.log(error);
            })
    }

    handleCancel() {
        this.cancelPopUp = true;
    }

    handleCancelNo() {
        this.cancelPopUp = false;
    }

    handleCancelYes() {
        this.deleteContentDocs();
        this.showData = false;
        this.numberofItems = null;
        this.resultData = null;
        this.displayResultData = null;
        this.cancelPopUp = false;
        this.pageCount = 1;
        this.pageSizeOptions = [
            { value: 10, selected: true },
            { value: 50, selected: false },
            { value: 100, selected: false },
        ];
    }

    deleteContentDocs() {
        if (this.contentDocId) {
            deleteContentDocumentFiles({ contentDocumentId: this.contentDocId })
                .then(result => {
                    this.contentDocId = null;
                    this.handleRemoveEventListner();

                })
                .catch(error => {
                    this.error = error;
                });
        }
    }

    handleRemoveEventListner() {
        window.removeEventListener('beforeunload', this.deleteContentDocs.bind(this));
    }

    handleChangePageSize(event) {
        this.pageSizeOptions.forEach(option => {
            if (option.value == event.currentTarget.dataset.value) {
                option.selected = true;
            } else {
                option.selected = false;
            }
        });
        this.resetPageNumberOptions();
    }

    resetPageNumberOptions() {
        this.pageNumberOptions = [];
        let pageSize = this.pageSizeOptions.find(element => element.selected).value;
        this.displayResultData = this.resultData.prodWrapList.slice(0, pageSize);
        this.pageCount = Math.ceil(this.resultData.prodWrapList.length / pageSize);
        if (this.pageCount > 1) {
            this.showPagination = true;
            let count = paginationNumbers > this.pageCount ? this.pageCount : paginationNumbers;
            for (let i = 1; i <= count; i++) {
                let selected = i == 1;
                this.pageNumberOptions.push({ value: i, selected: selected });
            }
            window.clearTimeout(this.delayTimeout);
            this.delayTimeout = setTimeout(() => {
                this.template.querySelector('[data-id="jumpToLeft"]').classList.add('inactive');
                this.template.querySelector('[data-id="chevronLeft"]').classList.add('inactive');
            }, DELAY);
        } else {
            this.showPagination = false;
        }
    }

    handlePageNumberClick(event) {
        this.changePage(parseInt(event.currentTarget.dataset.value));
    }

    handleFirstPage() {
        if (this.pageNumberOptions.find(element => element.selected).value != 1) {
            this.changePage(1);
        }
    }

    handlePrevious() {
        let currentPage = this.pageNumberOptions.find(element => element.selected).value;
        if (currentPage != 1) {
            this.changePage(currentPage - 1);
        }
    }

    handleNext() {
        let currentPage = this.pageNumberOptions.find(element => element.selected).value;
        if (currentPage != this.pageCount) {
            this.changePage(currentPage + 1);
        }
    }

    handleLastPage() {
        if (this.pageNumberOptions.find(element => element.selected).value != this.pageCount) {
            this.changePage(this.pageCount);
        }
    }

    changePage(pageIndex) {
        this.pageNumberOptions = [];
        let count = paginationNumbers > this.pageCount ? this.pageCount : paginationNumbers;
        this.pageNumberOptions.push({ value: pageIndex, selected: true });
        let incrementCount = 1;
        let decrementCount = 1;
        while (this.pageNumberOptions.length < count) {
            if (pageIndex + incrementCount < this.pageCount + 1) {
                this.pageNumberOptions.push({ value: pageIndex + incrementCount, selected: false });
                incrementCount++;
            }
            if (pageIndex - decrementCount > 0) {
                this.pageNumberOptions.unshift({ value: pageIndex - decrementCount, selected: false });
                decrementCount++;
            }
        }
        this.template.querySelector('[data-id="jumpToLeft"]').classList.remove('inactive');
        this.template.querySelector('[data-id="chevronLeft"]').classList.remove('inactive');
        this.template.querySelector('[data-id="jumpToRight"]').classList.remove('inactive');
        this.template.querySelector('[data-id="chevronRight"]').classList.remove('inactive');
        if (pageIndex == 1) {
            this.template.querySelector('[data-id="jumpToLeft"]').classList.add('inactive');
            this.template.querySelector('[data-id="chevronLeft"]').classList.add('inactive');

        } else if (pageIndex == this.pageCount) {
            this.template.querySelector('[data-id="jumpToRight"]').classList.add('inactive');
            this.template.querySelector('[data-id="chevronRight"]').classList.add('inactive');
        }
        let start = (this.pageNumberOptions.find(element => element.selected).value - 1) * this.pageSizeOptions.find(element => element.selected).value;
        let end = start + this.pageSizeOptions.find(element => element.selected).value;
        this.displayResultData = this.resultData.prodWrapList.slice(start, end);
    }

    closeToast() {
        this.showToast = false;
        window.clearTimeout(this.toastDelayTimeout);
        this.toastDelayTimeout = setTimeout(() => {
            let toast = this.template.querySelector('[data-id="toast"]');
            if (toast) {
                toast.classList.remove('visible');
            }
        }, TOASTDELAY);

    }

    handleNavigateTo(event) {
        event.preventDefault();
        const name = event.target.name;
        if (this.breadCrumbsMap[name]) {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: {
                    name: this.breadCrumbsMap[name]
                }
            });
        }
    }

    downloadTemplate() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: this.downloadLink
            }
        });
    }
}