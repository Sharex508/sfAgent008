import { LightningElement,api,track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import isguest from '@salesforce/user/isGuest';


const CARD_VISIBLE_CLASSES = 'fade slds-show';
const CARD_HIDDEN_CLASSES = 'fade slds-hide';
const DOT_VISIBLE_CLASSES = 'dot active';
const DOT_HIDDEN_CLASSES = 'dot';
const DEFAULT_TIMER = 8000;
export default class CustomCarousel extends NavigationMixin(LightningElement) {
    isGuest =isguest;
    slides = [];
    @track isUploadButton=false;
    slideIndex = 1;
    timer;
    @api 
    get slidesData(){   
        
        return this.slides;

    }

    set slidesData(data){
        
        this.slides = data.map((item,index)=>{
            return index === 0 ? {
                ...item,
                slideIndex: index + 1,
                cardClasses: CARD_VISIBLE_CLASSES,
                dotClasses: DOT_VISIBLE_CLASSES
            }:{
                ...item,
                slideIndex: index + 1,
                cardClasses: CARD_HIDDEN_CLASSES,
                dotClasses: DOT_HIDDEN_CLASSES
            }
        })
        
    }

    //logic for auto change of carousel image
    connectedCallback(){
        //dont change the carousel if the user is Guest
        if(!this.isGuest){
            this.timer = window.setInterval(()=>{
                this.slideSelectionHandler(this.slideIndex + 1);
            },DEFAULT_TIMER)
        }
        
    }

    currentslide(event){
        let slideIndex = Number(event.target.dataset.id);
        this.slideSelectionHandler(slideIndex);
    }

    backslide(){
        let slideIndex = this.slideIndex - 1;
        this.slideSelectionHandler(slideIndex);
    }

    forwardslide(){
        let slideIndex = this.slideIndex + 1;
        this.slideSelectionHandler(slideIndex);
    }

    slideSelectionHandler(id){
        if(id > this.slides.length){
            this.slideIndex = 1;
        }
        else if(id < 1){
            this.slideIndex = this.slides.length
        }
        else{
            this.slideIndex = id;
        }
        this.slides = this.slides.map(item=>{
            return this.slideIndex === item.slideIndex ? {
                ...item,
                cardClasses: CARD_VISIBLE_CLASSES,
                dotClasses: DOT_VISIBLE_CLASSES
            }:{
                ...item,
                cardClasses: CARD_HIDDEN_CLASSES,
                dotClasses: DOT_HIDDEN_CLASSES
            }
        })
    }
}