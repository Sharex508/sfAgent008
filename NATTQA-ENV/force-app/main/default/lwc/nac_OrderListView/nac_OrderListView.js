import { LightningElement, track, api } from 'lwc';
import communityId from '@salesforce/community/Id';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import fetchData from '@salesforce/apex/NAC_OrderController.fetchData';
import addtoCart from '@salesforce/apex/NAC_OrderController.addtoCart';
import naocapStartReorderSuccessMessage from '@salesforce/label/c.NAOCAP_Start_Reorder_Success_Message';
import naocapStartReorder100ItemWarning from '@salesforce/label/c.NAOCAP_Start_Reorder_100_items_Warning';

const objectApiName = 'Order';
const fieldSetName = 'NAOCAP_Order_List_View';
const sortFieldSetName = 'NAOCAP_Order_List_View_Sortable_Fields';
const standardCartErrorMessage = 'An Error occoured while adding the items to cart. Please contact your system admin for more details';
const standardErrorMessage = 'There was a error in retrieving the data. Please contact your system admin for more details';
const paginationNumbers = 5;
const DELAY = 500;
const SEARCHDELAY = 200;

export default class Nac_OrderListView extends NavigationMixin(LightningElement) {
    showPageSize = true;
    pageCount = 1;
    currentPage = 1;
    showPagination = false;
    delayTimeout;
    searchdDelayTimeout;
    showSpinner = false;
    showData = false;
    showWarehouseModal = false;
    defaultSortDirection = 'asc';
    sortDirection = 'asc';
    sortedBy;
    selectedWareHouse;
    selectedWareHouseName;
    orderId;
    openDisclaimerModal = false;
    @track notOrderableProductCode = [];
    @track columns;
    @track actualData;
    @track data;
    @api effectiveAccountId;
    @track pageNumberOptions = [];
    @track displayData;
    @track pageSizeOptions = [
        { value: 10, selected: false },
        { value: 25, selected: true },
        { value: 50, selected: false },
        { value: 100, selected: false },
    ];

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
        this.showSpinner = true;
        fetchData({ communityId: communityId, effectiveAccountId: this.resolvedEffectiveAccountId, fieldSetName: fieldSetName, sortFieldSetName: sortFieldSetName, objectName: objectApiName })
            .then(result => {
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
                    this.selectedWareHouse = result.wareHouse;
                    this.columns = result.field.fieldList;
                    this.columns.forEach(column => {
                        if (column.label == 'JDE Sales Order #') {
                            column.label = 'Sales Order #';
                        } else if (column.label == 'PO #') {
                            column.label = 'Customer PO #';
                        } else if (column.label == 'Order Number') {
                            column.label = 'Order Reference #';
                        } else if (column.label == 'NATT Order Status') {
                            column.label = 'Order Status';
                        } else if (column.label == 'Order Start Date'){
                            column.label = 'Ordered Date';
                            column.type = 'string';
                        }
                    });
                    
                    this.columns.push({
                        fieldName: "Id",
                        type: "lightningButtonRight",
                        typeAttributes: {
                            buttonLabel: 'Start Reorder',
                            showText: true,
                            textLabel: 'View Details'
                        }
                    });
                    this.actualData = result.sObjectList;
                    this.actualData.forEach( iterator =>{	
                        if(iterator.EffectiveDate != null){	
                            console.log('Ordered Date');
                            console.log(JSON.stringify(iterator));
                            console.log(iterator.EffectiveDate);
                            //let c= new Date(iterator.OrderedDate).toDateString();	
                            //iterator.OrderedDate=c;	
                        }	
                    })
                   /** this.actualData.forEach( iterator =>{	
                        if(iterator.OrderedDate != null){	
                            let c= new Date(iterator.OrderedDate).toDateString();	
                            iterator.OrderedDate=c;	
                        }	
                    })
                     */
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

    handleButtonClick(event) {
        event.stopPropagation();
        this.orderId = event.detail;
        if (!this.selectedWareHouse) {
            this.showWarehouseModal = true;
        } else {
            this.handleAddToCart();
        }
    }

    handleAddToCart() {
        this.showSpinner = true;
        this.notOrderableProductCode = [];
        this.selectedWareHouseName = this.selectedWareHouse == 'ANA' ? 'USA - Anaheim' : this.selectedWareHouse == 'PAN' ? 'Panama' : this.selectedWareHouse == 'CHI' ? 'Chile' : 'USA - Atlanta';
        addtoCart({ orderId: this.orderId, communityId: communityId, effectiveAccountId: this.resolvedEffectiveAccountId, wareHouse: this.selectedWareHouse })
            .then(result => {
                this.showSpinner = false;
                this.orderId = undefined;
                if (result.hasError) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: result.errorMessage,
                            variant: 'error',
                            mode: 'dismissable'
                        })
                    );
                    console.log(result.errorMessage);
                } else if (result.hasAllItemsNotOrderableError) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: result.errorMessageAllItemNotOrderable,
                            variant: 'error',
                            mode: 'dismissable'
                        })
                    );
                }else {
                    if(result.notOrderableProductCode && result.notOrderableProductCode.length > 0){
                        this.notOrderableProductCode = result.notOrderableProductCode;
                        this.openDisclaimerModal = true;
                    }
                    this.dispatchEvent(
                        new CustomEvent('cartchanged', {
                            bubbles: true,
                            composed: true
                        })
                    );
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: naocapStartReorderSuccessMessage,
                            message: naocapStartReorder100ItemWarning,
                            variant: 'success',
                            mode: 'sticky'
                        })
                    );
                }
            })
            .catch(error => {
                this.showSpinner = false;
                this.orderId = undefined;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: standardCartErrorMessage,
                        variant: 'error',
                        mode: 'dismissable'
                    })
                );
                console.log('Error' + JSON.stringify(error));
            });
    }

    handleWarehouseSelection(event) {
        this.showWarehouseModal = false;
        this.selectedWareHouse = event.detail.selectedWarehouse;
        this.handleAddToCart();
    }

    handleWarehouseSelectionModelClose() {
        this.showWarehouseModal = false;
    }

    handleTextClick(event) {
        event.stopPropagation();
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.detail,
                actionName: 'view'
            }
        });
    }

    handleCloseDisclaimerModal(){
        this.notOrderableProductCode = [];
        this.openDisclaimerModal = false;
    }

    onHandleSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        const cloneData = [...this.data];
        cloneData.sort(this.sortBy(sortedBy, sortDirection === 'asc' ? 1 : -1));
        this.data = cloneData;
        this.sortDirection = sortDirection;
        this.sortedBy = sortedBy;
        this.resetPageNumberOptions();
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
        console.log('field@@@@'+field);
            if (field == 'OrderedDate') {
                let c = new Date(a);
                let d = new Date(b);
                return reverse * ((c > d) - (d > c));
            } else {
                return reverse * ((a > b) - (b > a));
            }

        };
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
        this.displayData = this.data.slice(start, end);
    }

    handleSearch(event) {
        window.clearTimeout(this.searchdDelayTimeout);
        const searchKey = event.target.value;
        this.searchdDelayTimeout = setTimeout(() => {
            try {
                this.data = [];
                const filter = searchKey.toUpperCase();
                this.actualData.forEach(data => {
                    for (var key in data) {
                        if (data.hasOwnProperty(key)) {
                            if (String(data[key]).toUpperCase().indexOf(filter) > -1) {
                                this.data.push(data);
                                break;
                            }
                        }
                    }
                });
                this.resetPageNumberOptions();
            } catch (e) {
                console.log(e);
            }
        }, SEARCHDELAY);
    }
}