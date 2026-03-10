import { LightningElement, api, track, wire } from 'lwc';
import getAlerts from '@salesforce/apex/UCP_AlertCarouselController.getAlerts';
import communityBasePath from '@salesforce/community/basePath';
import DealerAlert from'@salesforce/label/c.Dealer_Alerts';
import DealerAlertErrorMessage from'@salesforce/label/c.Dealer_Alerts_ErrorMessage';
import CarouselMessage from'@salesforce/label/c.CarouselMessage';

const DEFAULT_PERCENT_WIDTH = 100;
const DEFAULT_SLIDES_NUMBER = 1;


export default class ucp_alertCarousel extends LightningElement {
    @track progress = 8000; 
    @api titleText;
    @track hasNext = false;
    @track hasPrev = false;
    @track countSlides = 1;
    @track showSpinner = true;
    @track showWarningMessage = false;
    @track errorMessage = '';
    @track alerts = [];
    @track currentPage = 1;

    label = {
      DealerAlert,
      DealerAlertErrorMessage,
      CarouselMessage
    };    

    connectedCallback() {
        getAlerts()
            .then(result => {
                if (result.success) {
                    this.alerts = result.data;

                    if (this.alerts.length == 0) {
                        this.showErrorMessage(this.label.DealerAlertErrorMessage);
                    }
                    
                    if (this.alerts.length > 0) {
                        this.alerts.forEach( (alert) => {
                            alert.url = communityBasePath + '/detail/' + alert.Id;
                        });
                        this._interval = setInterval(() => {  
                            const trackEl = this.template.querySelector('.carousel__track');
                            const slides = Array.from(trackEl.children);
                            console.log('set enter '+ slides.length);
                            let count = 1;
                            if(this.countSlides === 1){
                                this.hasNext = true;
                                this.hasPrev = false;
                            }
                            else if(this.countSlides === slides.length ){
                                this.countSlides = 0;
                                this.currentPage = 0;
                                trackEl.style.transform = 'translateX(0)';
                            }                   
                            if(this.hasNext == true && this.hasPrev == false){
                                if (this.countSlides <= slides.length-1) {
                                    this.goNext();                                                       
                                }
                            }
                        }, this.progress);
                    }              
                    
                    
                } else {
                    this.showErrorMessage(result.message);
                }

                this.showSpinner = false;

                
            })
            .catch(error => {
                console.log('error is: ' + JSON.stringify(error));                
                this.showSpinner = false;
            });
        
           
    }

    showErrorMessage(message) {
        this.showWarningMessage = true;
        this.errorMessage = message;
    }

    goPrev() {
        console.log('set enter goPrev ');
        this.countSlides--;
        this.currentPage--;
        let actualTransform = DEFAULT_PERCENT_WIDTH * this.countSlides;
        let nextTransform = (actualTransform) - 100;

        const trackEl = this.template.querySelector('.carousel__track');

        if (nextTransform >= 0) {
            trackEl.style.transform = 'translateX(-' + nextTransform + '%)';
        }

        this.setControlsVisibility();
    }   
    
    goNext() {
        console.log('set goNext '+ this.countSlides);
        /*if (this.countSlides <= 0) {
            this.countSlides = 1;
            this.currentPage = 1;
        }*/
        
        const trackEl = this.template.querySelector('.carousel__track');
        const slides = Array.from(trackEl.children);
        
        if (this.countSlides <= slides.length-1) {
            trackEl.style.transform = 'translateX(-' + DEFAULT_PERCENT_WIDTH * this.countSlides + '%)';
            this.countSlides++;
            this.currentPage++;
            console.log('set goNext countSlides++'+ this.countSlides);
        }
        this.setControlsVisibility();
    }
    
        setControlsVisibility() {
        const trackEl = this.template.querySelector('.carousel__track');
        const slides = Array.from(trackEl.children);
    
        const buttonLeft = this.template.querySelector('.carousel__button--left');
        const buttonRight = this.template.querySelector('.carousel__button--right');
    
        if (this.countSlides <= 1) {
            buttonLeft.style.display = 'none';
            buttonRight.style.display = 'block';
        } else if (this.countSlides > 1 && this.countSlides < slides.length) {
            buttonLeft.style.display = 'block'; 
            buttonRight.style.display = 'block';
        } else if (this.countSlides >= slides.length) {
            buttonLeft.style.display = 'block';
            buttonRight.style.display = 'none';
        } 
    }
    

}