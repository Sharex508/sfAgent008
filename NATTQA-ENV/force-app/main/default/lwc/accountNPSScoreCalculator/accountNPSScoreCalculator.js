import { LightningElement, track, api } from 'lwc';
import calculateScore from '@salesforce/apex/AccountNPSScoreCalculatorController.calculateScore';

export default class AccountNPScoreCalculatorLWC extends LightningElement {
    @api recordId;
    @api showGaugeChart = false;
    booLoading = true;
    @track responseData = {};
    selectedRange = 'This Year';

    connectedCallback() {
        this.booLoading = true;
        this.callServerForCalculation(this.recordId, this.selectedRange);
    }

    renderedCallback() {
        console.log('inside renderedcallback');
        this.styleGauge(this.responseData.decNPSScoreForAccount);
    }

    callServerForCalculation(recordId, dateRange) {
        console.log('callServerForCalculation, selectedRange ::: ', dateRange);
        console.log('callServerForCalculation, recordId ::: ', recordId);
        calculateScore({
            accountId : recordId , 
            strRange : dateRange
        }).then(result => {            
            console.log('result ::: ', result);
            this.responseData = JSON.parse(result);            
            this.booLoading = false;
        }).catch(error => {
            console.error('error in callServerForCalculation, details ::: ', error);
            this.booLoading = false;
        });
    }
    
    get timeRangeOptions() {
        return [
            { label: 'This Year', value: 'This Year' },
            { label: 'This Quarter', value: 'This Quarter' },
            { label: 'This Month', value: 'This Month' },
            { label: 'Last Year', value: 'Last Year' },
            { label: 'All Time', value: 'All Time' }
        ];
    }

    handleRangeChange(event) {
        this.selectedRange = event.detail.value;
        console.log('selectedRange ::: ', this.selectedRange);
        this.booLoading = true;
        this.callServerForCalculation(this.recordId, this.selectedRange);
    }

    handleRefresh(event) {
        this.booLoading = true;
        this.callServerForCalculation(this.recordId, this.selectedRange);        
    }

    get hideScore() {
        return this.responseData.strMessage === 'No responses returned';
    }

    styleGauge(score) {        
        this.setGaugeValue(score/100);
    }
    
    setGaugeValue(value) {        
        //value = 0.7;
        const finalScore = Math.round(value * 100);
        console.log('finalScore ::: ', finalScore);
        const gaugeFill = this.template.querySelector(".gauge__fill");
        const gaugeCover = this.template.querySelector(".gauge__cover");

        const gaugeFillColor = this.fetchGaugeFillColor(finalScore);
        
        console.log('gaugeFillColor ::: ', gaugeFillColor);
        console.log('value ::: ', value);
        const valueForRotation = value;
        console.log('valueForRotation ::: ', valueForRotation);
        
        if(gaugeFill) {            
            gaugeFill.style.transform = `rotate(${
                ((1 + valueForRotation)/2)/2
            }turn)`;
            gaugeFill.style.background = gaugeFillColor;
            
        }

        if(gaugeCover) {
            gaugeCover.textContent = `${finalScore}`;
            gaugeCover.style.color = gaugeFillColor;
        }      
    }

    fetchGaugeFillColor(score) {
        if(score <= -50) {
            return 'red';   
        }else if ( score >= -49 && score <= 5) {
            return 'orange';
        }else if ( score >= 6 && score <= 36 ) {
            return 'yellow';
        } else if ( score >= 37 ) {
            return 'green';
        }
    }
}