import { LightningElement, api } from 'lwc';

const DELAY = 300;

export default class Nac_OrderReview extends LightningElement {

    delayTimeout;
    requiredBool = false;

    @api orderInformation;
    @api downloadLink;

    handlePONumberchange(event) {
        window.clearTimeout(this.delayTimeout);
        let orderInfo = JSON.parse(JSON.stringify(this.orderInformation));
        orderInfo.purchaseOrderNo = event.detail.value;
        this.delayTimeout = setTimeout(() => {
            this.orderInformation = orderInfo;
            this.notifyAction();
        }, DELAY);
    }

    onHandleValueChange(event) {
        let orderInfo = JSON.parse(JSON.stringify(this.orderInformation));
        orderInfo.acceptedTerms = event.target.checked;
        this.orderInformation = orderInfo;
        this.notifyAction();
    }

    notifyAction() {
        this.dispatchEvent(
            new CustomEvent('orderinfo', {
                bubbles: true,
                composed: true,
                detail: this.orderInformation
            })
        );
    }
}