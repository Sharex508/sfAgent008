import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { CurrentPageReference } from 'lightning/navigation';
import NATT_WAREHOUSE_FIELD from '@salesforce/schema/WebCart.NATT_Warehouse__c';
import TOTAL_PRODUCT_COUNT_FIELD from '@salesforce/schema/WebCart.TotalProductCount';
import clearCart from '@salesforce/apex/CtmBuyerGroupMemberUpdate.clearCart';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import WarehouseLabel from '@salesforce/label/c.CTM_Warehouse_Price_Availability_Ordering_Redirect';

export default class NattCtmCartWarehouse extends LightningElement {
    @track recordId;           
    @track warehouse;
    @track totalProductCount;
    fields = [NATT_WAREHOUSE_FIELD,TOTAL_PRODUCT_COUNT_FIELD];

    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        if (pageRef && pageRef.attributes.recordId) {
            this.recordId = pageRef.attributes.recordId;
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: '$fields' })
    wiredRecord({ error, data }) {
        if (data) {
            this.warehouse = data.fields.NATT_Warehouse__c.value;
            this.totalProductCount = data.fields.TotalProductCount.value;
            this.checkWarehouse();
        } else if (error) {
            console.error('Error fetching warehouse field: ', error);
        }
    }

    checkWarehouse() {
        if (!this.warehouse) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Favor de seleccionar el Almacen para poder añadir refacciones al Carrito de Compras.',
                    variant: 'error',
                })
            );
            this.clearCartItems();
            // Redirect to home page
            //window.location.href = WarehouseLabel;
            setTimeout(() => {
                window.location.href = WarehouseLabel;
            }, 5000);
           
        }
    }
    clearCartItems() {
        console.log('I am in the clear cart Item');
        // Call the Apex method to clear the cart
        clearCart({ cartId: this.recordId })
            .then(() => {
                console.log('Cart cleared successfully.');
            })
            .catch(error => {
                console.error('Error clearing the cart: ', error);
            });
    }
}