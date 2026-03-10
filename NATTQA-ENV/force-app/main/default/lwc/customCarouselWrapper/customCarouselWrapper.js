import { LightningElement,api } from 'lwc';
import carouselData from '@salesforce/apex/NAC_B2BGetInfoController.getStaticResourceData';

export default class CustomCarouselWrapper extends LightningElement {
    slidesData = []
    slides = [];

    constructor(){
        super();
        carouselData()
            .then(result => {
                console.log(result)
                this.slides = result;
            })
            .catch(error => {
                console.log('Error' + JSON.stringify(error));
            });
    } 
}