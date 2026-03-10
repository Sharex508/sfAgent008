import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import returWarehouses from '@salesforce/apex/Nac_GetCustomSettingWareHouseData.returWarehouses';
import getSelectedWarehouse from '@salesforce/apex/Nac_GetCustomSettingWareHouseData.getSelectedWarehouse';
import chooseWareshouseLabel from '@salesforce/label/c.nac_ChooseWarehouselabel';
import SaveLabel from '@salesforce/label/c.nac_Save';
import communityId from '@salesforce/community/Id';
import updateTheCart from '@salesforce/apex/Nac_GetCustomSettingWareHouseData.updateTheCart';
import redirected_To_external from '@salesforce/label/c.Redirected_To_external';

export default class Nac_wareHouseModal extends LightningElement {


    @track WareHousesData;
    @track WareHouses;
    @track error;
    @track isShowModal;
    @api ClickedWarehouse;
    @track selectedWareHouse;
    @api effectiveAccountId;
    @api openWarehouseModal;
    @api boolitem;
    showBackdrop = true;
    renderOnce = false;

    @api
    get disableSldsBackdropOpen() {
        return this.showBackdrop;
    }
    set disableSldsBackdropOpen(value) {
        this.showBackdrop = true;
        if (value && value == true) {
            this.showBackdrop = false;
        }
    }

    labels = {
        chooseWareshouseLabel,
        SaveLabel,
        redirected_To_external
    };

    effectiveAccountId = this.effectiveAccountId;
    boolitem = this.boolitem;

    connectedCallback() {
        try {
            returWarehouses({ communityId: communityId, effectiveAccountId: this.effectiveAccountId, activeCartOrId: 'active' })
                .then(result => {
                    this.selectedWareHouse = result[0].WarehouseStamped;
                    this.WareHouses = result;
                    if (this.selectedWareHouse == null) {
                        this.isShowModal = true;
                    } else {
                        this.isShowModal = false;
                    }
                    if (this.openWarehouseModal == true && this.selectedWareHouse != null) {
                        this.isShowModal = true;
                    }
                })
                .catch(error => {
                    this.error = error;
                });

        } catch (e) {
            console.log(e);
        }
    }

    renderedCallback() {
        if (!this.renderOnce) {
            if (this.template.querySelector('[data-id="modalContainer"]')) {
                if (!this.showBackdrop) {
                    this.template.querySelector('[data-id="modalContainer"]').classList.add('fullWidth');
                } else {
                    this.template.querySelector('[data-id="modalContainer"]').classList.remove('fullWidth');
                }
                this.renderOnce = true;
            }
        }
    }

    handleSave() {
        this.ClickedWarehouse = this.template.querySelector('input[name = "warehouse"]:checked').value;
        getSelectedWarehouse({ ClickedWarehouse: this.template.querySelector('input[name = "warehouse"]:checked').value })
            .then(result => {
                this.WareHousesData = result;
                for (var i = 0; i < result.length; i++) {
                    if (this.boolitem == false || this.boolitem == undefined) {
                        if (result[i].externalurl != null && result[i].isActive == true && result[i].Redirection == true) {
                            this.dispatchEvent(
                                new CustomEvent('calltoclose', {
                                    detail: true
                                })
                            );
                            var url = result[i].externalurl;
                            window.open(url, "_blank");
                            this.openWarehouseModal = false;
                        }
                        else {
                            this.showNotification();
                            this.updateCartItems();
                        }
                    }
                    if (this.boolitem == true) {
                        if (result[i].externalurl != null && result[i].isActive == true && result[i].Redirection == true) {
                            this.dispatchEvent(
                                new CustomEvent('calltoclose', {
                                    detail: true
                                })
                            );
                            var url = result[i].externalurl;
                            window.open(url, "_blank");
                            this.openWarehouseModal = false;
                        }
                        else {
                            this.showNotification();
                            this.updateCartItemsBool();
                        }
                    }
                }
                this.isShowModal = false;
            })
            .catch(error => {
                this.error = error;
                this.WareHouses = undefined;
            });

    }

    updateCartItems() {
        this.ClickedWarehouse = this.template.querySelector('input[name = "warehouse"]:checked').value;
        updateTheCart({ communityId: communityId, effectiveAccountId: this.effectiveAccountId, activeCartOrId: 'active', ClickedWarehouse: this.ClickedWarehouse })
            .then(result => {
                this.selectedWareHouse = result.Warehouse_selected__c;
                console.log(this.selectedWareHouse);
                this.dispatchEvent(
                    new CustomEvent('calltoaction', {
                        detail: {
                            selectedWarehouse: this.selectedWareHouse
                        }
                    })
                );
                this.dispatchEvent(
                    new CustomEvent('therefreshpage', {
                        detail: true
                    })
                );
                this.isShowModal = false;
                this.openWarehouseModal = false;
            })
            .catch(error => {
                this.error = error;
                this.selectedWareHouse = undefined;
            });
    }

    updateCartItemsBool() {
        this.ClickedWarehouse = this.template.querySelector('input[name = "warehouse"]:checked').value;
        updateTheCart({ communityId: communityId, effectiveAccountId: this.effectiveAccountId, activeCartOrId: 'active', ClickedWarehouse: this.ClickedWarehouse })
            .then(result => {
                this.selectedWareHouse = result.Warehouse_selected__c;
                this.dispatchEvent(
                    new CustomEvent('callbackaction', {
                        detail: {
                            selectedWarehouse: this.selectedWareHouse
                        }
                    })
                );
                this.dispatchEvent(
                    new CustomEvent('therefreshpage', {
                        detail: true
                    })
                );
                this.isShowModal = false;
                this.openWarehouseModal = false;
            })
            .catch(error => {
                this.error = error;
                this.selectedWareHouse = undefined;
            });
    }

    showNotification() {
        this.isShowModal = false;
        const event = new ShowToastEvent({
            title: 'Warehouse successfully selected',
            variant: 'success',
            message: 'You can now add items to your cart based on the selection you have made',
        });
        this.dispatchEvent(event);
        this.isShowModal = false;
    }

    hideModalBox() {
        this.isShowModal = false;
    }
}