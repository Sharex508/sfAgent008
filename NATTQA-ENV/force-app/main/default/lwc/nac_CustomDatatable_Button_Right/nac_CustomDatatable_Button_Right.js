import { LightningElement, api } from 'lwc';

export default class Nac_CustomDatatable_Button_Right extends LightningElement {

    @api buttonLabel;
    @api showText;
    @api textLabel;
    @api value;

    handleClick(){
        this.dispatchEvent(
            new CustomEvent('buttonclick', {
                bubbles: true,
                composed: true,
                detail: this.value
            })
        );
    }

    handleView(){
        this.dispatchEvent(
            new CustomEvent('textclick', {
                bubbles: true,
                composed: true,
                detail: this.value
            })
        );
    }
}