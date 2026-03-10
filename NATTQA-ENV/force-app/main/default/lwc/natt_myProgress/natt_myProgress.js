import { LightningElement, api, track, wire } from 'lwc';
import getMyProgressSummary from '@salesforce/apex/NATT_MyProgressController.getMyProgressSummary';
import QuoteInProg from'@salesforce/label/c.Quotes_in_Progress';
import OrderInProg from'@salesforce/label/c.Orders_in_Progress'; 
import CaseInProg from'@salesforce/label/c.Cases_in_Progress';
import OrderInProgUnit from'@salesforce/label/c.Unit';
import OrderInProgParts from'@salesforce/label/c.Parts';
import ClaimInProg from'@salesforce/label/c.Claims_in_Progress';
import PeriodThisDay from'@salesforce/label/c.This_Day';
import PeriodThisWeek from'@salesforce/label/c.This_Week';
import PeriodThisMonth from'@salesforce/label/c.This_Month';

export default class Natt_myProgress extends LightningElement {

    @api titleText = 'My Progress';
    @api period = 'Week';
    
    @track showSpinner = true;
    @track progressData;
    @track defaultValue;
    @track quoteIsAccessible = true;
    @track orderIsAccessible = true;
    @track caseIsAccessible = true;
    @track claimIsAccessible = true;
    
    label = {
        QuoteInProg,
        OrderInProg,
        CaseInProg,
        OrderInProgUnit,
        OrderInProgParts,
        ClaimInProg,
        PeriodThisDay,
        PeriodThisWeek,
        PeriodThisMonth
    };

    get optionsPeriod() {
        return [
            { label: this.label.PeriodThisDay, value: 'Day' },
            { label: this.label.PeriodThisWeek, value: 'Week' },
            { label: this.label.PeriodThisMonth, value: 'Month' },
        ];
    }

    connectedCallback() {
        this.getData();            
    }
    
    renderedCallback() {
        this.defaultValue = this.period;
    }

    getData() {
        getMyProgressSummary({period: this.period})
            .then(result => {
                this.progressData = result;
                
                this.showSpinner = false;

                this.quoteIsAccessible = result.quoteIsAccessible;
                this.orderIsAccessible = result.orderIsAccessible;
                this.caseIsAccessible = result.caseIsAccessible;
                this.claimIsAccessible = result.claimIsAccessible;
            })
            .catch(error => {
                console.log('error is: ' + JSON.stringify(error));                
                this.showSpinner = false;
            });
    }

    handleChangePeriod(event) {
        this.showSpinner = true;
        this.period = event.detail.value;
        this.getData();
    }

}