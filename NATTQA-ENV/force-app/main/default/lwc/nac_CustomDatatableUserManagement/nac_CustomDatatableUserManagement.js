import LightningDatatable from 'lightning/datatable';
import buttonRight from './nac_DataTypeUserManagement_Button.html';

export default class Nac_CustomDatatableUserManagement extends LightningDatatable {
    static customTypes = {
        lightningButtonRight: {
            template: buttonRight,
            typeAttributes: ['buttonLabel','showText','textLabel']
        }
    };
}