import { LightningElement, api, track, wire } from 'lwc';
import getRecentlyModifiedArticles from '@salesforce/apex/NATT_ArticleCarouselRecentlyController.getRecentlyModifiedArticles';
import nattAssets from '@salesforce/resourceUrl/NATT_Community_Assets';
import LANG from '@salesforce/i18n/lang';

const DEFAULT_TOTAL_RECORDS = 9;
let countSlides = 1;
let refreshIntervalId;

export default class Natt_articleCarouselRecentlyModified extends LightningElement {

    @api titleText;
    @api carouselTransitionTime = 5;

    @track showSpinner = true;
    @track showWarningMessage = false;
    @track articles = [];
    @track fullArticles = [];
    @track currentPage = 1;
    @track hasRendered = true;
    @track isAccessible = true;
    @track userLang;
    @track newArray ={}
    @track showStatic = false;
    @track article_order;

    connectedCallback() {
        this.userLang = LANG;
        console.log('userLang:'+this.userLang);
        this.invokeGetRecentlyModifiedArticles();
    }

    renderedCallback() {
       
    }

    async invokeGetRecentlyModifiedArticles() {        
        try {
            const result = await getRecentlyModifiedArticles();
            
            if (result.success) {
                result.data.forEach( (article, index) => {
                    article.iconImage = nattAssets + '/CommunityAssets/icons/' + article.iconType + '.png';
                    article.image = nattAssets + '/CommunityAssets/carrouselArticleTypeImage/' + article.image +'_'+this.userLang+ '.png';
                    article.iconType = article.iconType+'-'+this.userLang;
                });
                
                this.fullArticles = result.data;
                this.articles = result.data.slice(0, DEFAULT_TOTAL_RECORDS);
                this.showSpinner = false;
                
                if (this.articles.length == 0) {
                    this.showWarningMessage = true;
                }

            } else {
                if (!result.isAccessible) {
                    this.isAccessible = false;
                    this.showWarningMessage = true;
                }
            }

            await this.setFirstChildAsActive();
            await this.startCarousel();

        } catch (error) {
            console.log('error is: ' + JSON.stringify(error));                
            this.showSpinner = false;
        }
        
    }

    startCarousel() {
        this.setFirstChildAsActive();
        refreshIntervalId = setInterval(function() {
            this.showStatic = false; //
            if (countSlides == DEFAULT_TOTAL_RECORDS || countSlides == this.articles.length) {
                this.setFirstChildAsActive();

                return false;
            }

            countSlides++;
            this.currentPage++;
            
            let activeSlide = this.template.querySelector('.activeSlide');

            if (activeSlide != null) {
                activeSlide.classList.remove('activeSlide');
            
                if (activeSlide.nextElementSibling != null)
                    activeSlide.nextElementSibling.classList.add('activeSlide');
            }
            
            let activeIcon = this.template.querySelector('.col-icon.activeSlide');

            if (activeIcon != null) {
                activeIcon.classList.remove('activeSlide');

                if (activeIcon.nextElementSibling != null)
                    activeIcon.nextElementSibling.classList.add('activeSlide');
            }
            
        }.bind(this), this.carouselTransitionTime * 1000);
    }
    
    setFirstChildAsActive() {
        countSlides = 1;
        this.currentPage = 1;
        
        const carouselBody = this.template.querySelector('.carousel__body');
        if (carouselBody != null) {

            if (carouselBody.lastChild != null)
                carouselBody.lastChild.classList.remove('activeSlide');

            if (carouselBody.firstChild != null)
                carouselBody.firstChild.classList.add('activeSlide');
        }
        
        const carouselIcons = this.template.querySelector('.carousel__icons');
        if (carouselIcons != null) {

            if (carouselIcons.lastChild != null)
                carouselIcons.lastChild.classList.remove('activeSlide');
            
            if (carouselIcons.firstChild != null)
                carouselIcons.firstChild.classList.add('activeSlide');
        }

    }

    /*gotoSlide(event) {
        countSlides = parseInt(event.srcElement.getAttribute('data-index')) + 1;

        let slideId = event.srcElement.id;

        this.template.querySelectorAll('.carousel__slide').forEach((slide)=> slide.classList.remove('activeSlide'));
        this.template.querySelectorAll('.iconImage').forEach((slide)=> slide.classList.remove('activeSlide'));
        //this.template.querySelector('.carousel__icons');

        this.template.querySelector('.carousel__slide#'+slideId).classList.add('activeSlide');
        this.template.querySelector('.iconImage#'+slideId).classList.add('activeSlide');

        clearInterval(refreshIntervalId);
        this.startCarousel();
    }*/


    onClickHandler(event){
        clearInterval(refreshIntervalId);
        let activeIcon = this.template.querySelector('.col-icon.activeSlide');

        if (activeIcon != null) {
            activeIcon.classList.remove('activeSlide');
        }
        let divId = event.target.id;
        divId = divId.substring(0,divId.length-3);
        this.articles.map(art=>{
            art.className = 'iconImage';
            if(art.id === divId){
                this.newArray = art;
                art.className = 'iconImageSelect';
                this.article_order = this.articles.indexOf(this.newArray)+1; 
            }
        })
        if(Object.keys(this.newArray).length >0){
            this.showStatic = true;
        }

        //let timeout = setTimeout(this.startCarousel(), 60000);
        
    }
}