import { LightningElement, track } from 'lwc';
import communityId from '@salesforce/community/Id';
import { NavigationMixin } from 'lightning/navigation';
import getProductCategory from '@salesforce/apex/NAC_B2BGetInfoController.getProductCategory';
import getProductPath from '@salesforce/apex/NAC_B2BGetInfoController.getProductPath';
import categoriesLabel from '@salesforce/label/c.nac_Categories';
import allProductsLabel from '@salesforce/label/c.nac_AllProducts';
import subColumn from '@salesforce/label/c.NAOCAP_Number_of_Subcategories_columns';

const defaultNumberOfSubColumns = 4;

export default class Nac_verticalCategory extends NavigationMixin(LightningElement) {

    @track categoryTree;
    @track subcategoryTree;
    @track formattedSubcategoryTree;
    @track categorydata;
    subcategoryClass;
    openMenu = [];
    subcategoryName
    topMostParentCategoryId;
    label = {
        categoriesLabel,
        allProductsLabel,
        subColumn
    };
    connectedCallback() {
        getProductCategory({ communityId: communityId })
            .then(result => {
                try {
                    this.categorydata = result.productCategoryList;
                    this.topMostParentCategoryId = result.topMostParentCategoryId;
                    this.categorydata.forEach(element => {
                        if (!element.hasOwnProperty('ParentCategoryId')) {
                            element['ParentCategoryId'] = null;
                        }
                    });
                    this.categoryTree = this.formTree(this.topMostParentCategoryId);
                }
                catch (error) {
                    console.log(JSON.stringify(error.message));
                }
            })
            .catch(error => {
                console.log('Error' + JSON.stringify(error));
            });
    }

    renderedCallback() {
        let categories = this.template.querySelector('[data-item="categories"]');
        if (categories) {
            let overlay = this.template.querySelector('[data-item="overlay"]');
            if (overlay) {
                overlay.style.height = categories.offsetHeight + "px";
            }
        }
    }

    formTree(parentId) {
        const nest = (items, Id = parentId, link = 'ParentCategoryId') => items
            .filter(item => item[link] === Id)
            .map(item => ({
                ...item,
                children: nest(items, item.Id),
                childrenEmpty: (nest(items, item.Id).length === 0 ? true : false)
            }));
        return nest(this.categorydata);
    }

    openToggle(event) {
        this.resetMenu();
        this.openMenu.push(event.target.dataset.item);
        let overlay = this.template.querySelector('[data-item="overlay"]');
        if (overlay) {
            let selectedMenu = '[data-item="' + event.target.dataset.item + '"]';
            this.template.querySelector(selectedMenu).classList.add('selected');
            this.subcategoryTree = this.formTree(event.target.dataset.item);
            this.categorydata.forEach(element => {
                if (element.Id === event.target.dataset.item) {
                    element.Open = true;
                    this.subcategoryName = element.Name;
                }
            });
            this.categoryTree = this.formTree(this.topMostParentCategoryId);
            let categories = this.template.querySelector('[data-item="categories"]');
            if (categories) {
                let width = "calc(100% - " + (categories.offsetWidth) + "px - 20px)";
                overlay.style.width = width;
            } else {
                overlay.style.width = "66%";
            }
            this.formColumns();
        }
    }

    formColumns(){
        if(this.categoryTree && this.subcategoryTree){
            this.formattedSubcategoryTree = [];
            let numberOfSubColumns = isNaN(this.label.subColumn) ? defaultNumberOfSubColumns : Number(this.label.subColumn);
            this.subcategoryClass = 'slds-col slds-size_1-of-' + numberOfSubColumns.toString();
            let columnDataCount = ((this.subcategoryTree.length/this.categoryTree.length) > numberOfSubColumns) ? Math.ceil(this.subcategoryTree.length/numberOfSubColumns) : this.categoryTree.length;
            let column = [];
            this.subcategoryTree.forEach(cat => {
                column.push(cat);
                if(column.length == columnDataCount){
                    this.formattedSubcategoryTree.push(column);
                    column = [];
                }
            });
            if(column.length > 0){
                this.formattedSubcategoryTree.push(column);
            }

        }
    }

    closeToggle(event) {
        let overlay = this.template.querySelector('[data-item="overlay"]');
        if (overlay) {
            let selectedMenu = '[data-item="' + event.target.dataset.item + '"]';
            this.template.querySelector(selectedMenu).classList.remove('selected');
            this.subcategoryTree = [];
            this.formattedSubcategoryTree = [];
            this.subcategoryName = '';
            overlay.style.width = "0%";
            this.categorydata.forEach(element => {
                if (element.Id === event.target.dataset.item) {
                    element.Open = false;
                }
            });
            this.categoryTree = this.formTree(this.topMostParentCategoryId);
        }
    }

    searchProduct(event) {
        getProductPath({ communityId: communityId, productCategoryId: event.target.dataset.item })
            .then(result => {
                try {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__webPage',
                        attributes: {
                            url: result
                        }
                    });
                }
                catch (error) {
                    console.log(JSON.stringify(error.message));
                }
            })
            .catch(error => {
                console.log('Error' + JSON.stringify(error));
            });
    }

    handleCloseSubMenu() {
        this.resetMenu();
        let overlay = this.template.querySelector('[data-item="overlay"]');
        if (overlay) {
            this.subcategoryTree = [];
            this.formattedSubcategoryTree = [];
            this.subcategoryName = '';
            overlay.style.width = "0%";
        }
    }

    resetMenu() {
        if (this.openMenu.length > 0) {
            this.openMenu.forEach(id => {
                let menu = '[data-item="' + id + '"]';
                this.template.querySelector(menu).classList.remove('selected');
                this.categorydata.forEach(element => {
                    element.Open = false;
                });
                this.categoryTree = this.formTree(this.topMostParentCategoryId);
            });
        }
        this.openMenu = [];
    }
}