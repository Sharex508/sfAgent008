import { LightningElement, api, track } from 'lwc';
import communityId from '@salesforce/community/Id';
import addtoCart from '@salesforce/apex/NAC_OrderController.addtoCart';
import getCartDetails from '@salesforce/apex/Nac_GetCustomSettingWareHouseData.getCartDetails';
import naocapStartReorderAddingMessage from '@salesforce/label/c.NAOCAP_Start_Reorder_Adding_Message';
import naocapStartReorderSuccessMessage from '@salesforce/label/c.NAOCAP_Start_Reorder_Success_Message';
import naocapStartReorderPopUpDuraation from '@salesforce/label/c.NAOCAP_Start_Reorder_Pop_Up_Duration';
import naocapStartReorder100ItemWarning from '@salesforce/label/c.NAOCAP_Start_Reorder_100_items_Warning';

const DELAY = 2000;
const MOREDELAY = 5000;

export default class Nac_StartReorderLWC extends LightningElement {

    @api recordId;
    @api effectiveAccountId;
    loading = true;
    error = false;
    errorNotOrderable = false;
    delayTimeout;
    selectedWareHouse;
    selectedWareHouseName;
    showWarehouseModal;
    disableSldsBackdropOpen = true;
    openDisclaimerModal = false;
    @track notOrderableProductCode = [];
    label = {
        naocapStartReorderAddingMessage,
        naocapStartReorderSuccessMessage,
        naocapStartReorder100ItemWarning
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
        this.loading = true;
        this.error = false;
        
        getCartDetails({communityId: communityId, effectiveAccountId: this.resolvedEffectiveAccountId, activeCartOrId: 'active'})
            .then(result => {
                this.selectedWareHouse = result;
                if (!this.selectedWareHouse) {
                    this.showWarehouseModal = true;
                } else {
                    this.handleAddToCart();
                }
            })
            .catch(error => {
                this.loading = false;
                this.error = true;
                console.log('Error' + JSON.stringify(error));
                window.clearTimeout(this.delayTimeout);
                this.delayTimeout = setTimeout(() => {
                    this.dispatchEvent(
                        new CustomEvent('close', {
                            bubbles: true,
                            composed: true,
                            detail: true
                        })
                    );
                }, DELAY);
            });
    }

    handleAddToCart() {
        this.notOrderableProductCode = [];
        this.selectedWareHouseName = this.selectedWareHouse == 'ANA' ? 'USA - Anaheim' : this.selectedWareHouse == 'PAN' ? 'Panama' : this.selectedWareHouse == 'CHI' ? 'Chile' : 'USA - Atlanta';
        addtoCart({ orderId: this.recordId, communityId: communityId, effectiveAccountId: this.resolvedEffectiveAccountId, wareHouse: this.selectedWareHouse })
            .then(result => {
                if (result.hasError) {
                    this.loading = false;
                    this.error = true;
                    console.log(result.errorMessage);
                } else if (result.hasAllItemsNotOrderableError) {
                    this.loading = false;
                    this.errorNotOrderable = true;
                    console.log(result.errorMessage);
                }
                else {
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
                    this.loading = false;
                    this.error = false;
                }
                window.clearTimeout(this.delayTimeout);
                if(!this.openDisclaimerModal){
                    let timeOut;
                    try{
                        timeOut = parseInt(naocapStartReorderPopUpDuraation);
                    }catch(e){
                        timeOut = MOREDELAY;
                    }

                    this.delayTimeout = setTimeout(() => {
                        this.dispatchEvent(
                            new CustomEvent('close', {
                                bubbles: true,
                                composed: true,
                                detail: true
                            })
                        );
                    }, timeOut);
                }
            })
            .catch(error => {
                this.loading = false;
                this.error = true;
                console.log('Error' + JSON.stringify(error));
                window.clearTimeout(this.delayTimeout);
                this.delayTimeout = setTimeout(() => {
                    this.dispatchEvent(
                        new CustomEvent('close', {
                            bubbles: true,
                            composed: true,
                            detail: true
                        })
                    );
                }, DELAY);
            });
    }

    handleWarehouseSelection(event) {
        this.showWarehouseModal = false;
        this.selectedWareHouse = event.detail.selectedWarehouse;
        this.handleAddToCart();
    }

    handleCloseDisclaimerModal(){
        this.dispatchEvent(
            new CustomEvent('close', {
                bubbles: true,
                composed: true,
                detail: true
            })
        );
    }

    handleModelClose(){
        this.showWarehouseModal = false;
        this.dispatchEvent(
            new CustomEvent('close', {
                bubbles: true,
                composed: true,
                detail: true
            })
        );
    }
}