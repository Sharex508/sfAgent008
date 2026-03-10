import { LightningElement, track, api } from 'lwc';
import fetchData from '@salesforce/apex/nac_UserManagementController.fetchData';
import getContactRt from '@salesforce/apex/nac_UserManagementController.getContactRt';
import checkPartContactType from '@salesforce/apex/nac_UserManagementController.checkPartContactType';
import updateContactRecord from '@salesforce/apex/nac_UserManagementController.updateContactRecord';
import deactivateContactRecord from '@salesforce/apex/nac_UserManagementController.deactivateContactRecord';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

const fieldSetName = 'NAOCAP_Contact_List_View';
const sortFieldSetName = 'NAOCAP_Contact_List_View_Sortable_Fields';
const objectApiName = 'Contact';
const standardErrorMessage = 'There was a error in retrieving the data. Please contact your system admin for more details';
const paginationNumbers = 5;
const DELAY = 500;

export default class Nac_UserManagement extends NavigationMixin(LightningElement) {
    showData = false;
    showPageSize = true;
    showModal = false;
    showModalDelete = false;
    @track currContactRecordId;
    pageCount = 1;
    showPagination = false;
    delayTimeout;
    defaultSortDirection = 'asc';
    sortDirection = 'asc';
    sortedBy;
    contactRtId;
    isPartContactType
    @track columns;
    @api effectiveAccountId;
    @track actualData;
    @track data;
    @track displayData;
    @track pageNumberOptions = [];
    @track conData;
    @track pageSizeOptions = [
        { value: 10, selected: true },
        { value: 25, selected: false },
        { value: 50, selected: false },
        { value: 100, selected: false },
    ];
    @api showActions = false;


    connectedCallback() {
        this.showSpinner = true;
        checkPartContactType()
            .then(result => {
                this.isPartContactType = result;
            })
            .catch(error => {
                this.showSpinner = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: standardErrorMessage,
                        variant: 'error',
                        mode: 'dismissable'
                    })
                );
                console.log('Error' + JSON.stringify(error));
            });
        //fetch Contact fieldsets and prepare column Names
        fetchData({ fieldSetName: fieldSetName, sortFieldSetName: sortFieldSetName, objectName: objectApiName, effectiveAccountId: this.effectiveAccountId })
            .then(result => {
                // Stop spinner
                this.showSpinner = false;
                if (result.hasError) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: standardErrorMessage,
                            variant: 'error',
                            mode: 'dismissable'
                        })
                    );
                    console.log(result.errorMessage);
                } else {
                    this.columns = result.field.fieldList;
                    this.columns.forEach(column => {

                        if (column.label == 'Title') {
                            column.label = 'Job Title';
                        }

                    });

                    if (this.isPartContactType) {
                        this.columns.push({
                            label: 'Actions',
                            fieldName: "Id",
                            type: "lightningButtonRight",
                            typeAttributes: {
                                buttonLabel: 'Edit',
                                showText: true,
                                textLabel: 'Deactivate'
                            }
                        });
                    }
                    this.actualData = result.sObjectList;
                    this.data = this.actualData;
                    this.showData = true;
                    this.resetPageNumberOptions();
                }
            })
            .catch(error => {
                this.showSpinner = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: standardErrorMessage,
                        variant: 'error',
                        mode: 'dismissable'
                    })
                );
                console.log('Error' + JSON.stringify(error));
            });


    }

    handleRequestNewContact(event) {
        event.stopPropagation();
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/new-user/'
            }
        });

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
        this.displayData = this.data.slice(0, pageSize);
        this.pageCount = Math.ceil(this.data.length / pageSize);
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

    onHandleSort(event) {
        try {
            const { fieldName: sortedBy, sortDirection } = event.detail;
            const cloneData = [...this.data];
            cloneData.sort(this.sortBy(sortedBy, sortDirection === 'asc' ? 1 : -1));
            this.data = cloneData;
            this.sortDirection = sortDirection;
            this.sortedBy = sortedBy;
            this.resetPageNumberOptions();

        } catch (ex) {
            console.log(ex);

        }
    }

    sortBy(field, reverse, primer) {
        const key = primer
            ? function (x) {
                return primer(x[field]);
            }
            : function (x) {
                return x[field];
            };
        return function (a, b) {
            a = key(a);
            b = key(b);
            return reverse * ((a > b) - (b > a));
        };
    }




    handleButtonClick(event) {
        this.currContactRecordId = JSON.stringify(event.detail);
        this.contactRtId = getContactRt();
        this.showModal = true;
        event.stopPropagation();
    }

    handleTextClick(event) {
        this.currContactRecordId = JSON.stringify(event.detail);
        this.showModalDelete = true;
    }

    hideModalBox(event) {
        this.showModalDelete = false;
    }

    handleDelete(event) {
        let currRecId = this.currContactRecordId.replaceAll("\"", "");
        deactivateContactRecord({ recordId: currRecId })
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
                        const event = new ShowToastEvent({
                            title: 'Success',
                            message: 'Contact deleted successfully',
                            variant: 'success'
                        });
                        this.dispatchEvent(event);
                        this.showModalDelete = false;
                        location.reload();
                    }
                }
                catch (error) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: result.errorMessage,
                            variant: 'error',
                            mode: 'dismissable'
                        })
                    );
                    console.log(JSON.stringify(error.message));
                }
            })
            .catch(error => {
                this.showSpinner = false;

                this.showModalDelete = false;

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: JSON.stringify(error.body.message),
                        variant: 'error',
                        mode: 'dismissable'
                    })
                );

                console.log('Error' + JSON.stringify(error.body.message));
            });

    }
    handleContactEditLoad(event) {
        try {
            this.showSpinner = true;
            let currRecord = [];
            this.actualData.forEach(data => {
                for (var key in data) {
                    if (data.hasOwnProperty(key)) {
                        let currConId = this.currContactRecordId;
                        let result = currConId.replaceAll("\"", "");
                        if (key == 'Id' && data[key] == result) {
                            currRecord.push(data);
                            this.conData = currRecord;
                            break;
                        }
                    }
                }
            });
            const inputFields = this.template.querySelectorAll(
                'lightning-input-field'
            );
            this.conData.forEach(data => {
                for (var key in data) {
                    if (inputFields) {
                        inputFields.forEach(field => {
                            if (field.fieldName == key)
                                field.value = data[key];
                        });
                    }
                }
            });
            this.showSpinner = false;
        } catch (ex) {
            console.log(ex);
        }
    }

    closeModal() {
        this.showModal = false;
    }


    handleContactEditSubmit(event) {
        event.preventDefault();
        const fields = event.detail.fields;
        this.showSpinner = true;
        let currRecId = this.currContactRecordId.replaceAll("\"", "");
        updateContactRecord({ contactRecord: fields, recordId: currRecId })
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
                        const event = new ShowToastEvent({
                            title: 'Success',
                            message: 'Contact saved successfully',
                            variant: 'success'
                        });
                        this.dispatchEvent(event);
                        this.showModal = false;
                        location.reload();
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

    handleContactEditSuccess() {

    }

    handleCancel() {
        this.showModal = false;
    }

    handleContactEditError(event) {
        this.template.querySelectorAll('lightning-input-field').forEach(element => element.reportValidity());
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

    handlePageNumberClick(event) {
        this.changePage(parseInt(event.currentTarget.dataset.value));
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
        this.displayData = this.data.slice(start, end);
    }

}