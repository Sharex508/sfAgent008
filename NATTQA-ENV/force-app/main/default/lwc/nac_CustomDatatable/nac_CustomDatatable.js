import LightningDatatable from 'lightning/datatable';
import buttonRight from './nac_DataTypeButtonRight.html';

export default class Nac_CustomDatatable extends LightningDatatable {
    static customTypes = {
        lightningButtonRight: {
            template: buttonRight,
            typeAttributes: ['buttonLabel','showText','textLabel']
        }
    };

}