import { LightningElement,api,wire } from 'lwc';
import getProductCategory from '@salesforce/apex/NATT_TesTrademarkCon.getProductCategory';
import { CurrentPageReference } from 'lightning/navigation';

export default class Natt_tesTrademark extends LightningElement {
    @api recordId;
    categoryName;
    currentPageReference;

    @wire(CurrentPageReference)
    wiredCurrentPageReference(currentPageReference){
        console.log('currentPageReference:'+JSON.stringify(currentPageReference.state));
        this.currentPageReference = currentPageReference;    
        if(this.currentPageReference?.state?.c__results_layout_state){    
            let tempId = JSON.parse(this.currentPageReference.state.c__results_layout_state);
            if(tempId.category_id){
                this.recordId=tempId.category_id;
            }
        }
    }

    

    @wire(getProductCategory, { recordId: '$recordId' })
    wiredProductCategory({error,data}){
        if(data){
            console.log('data:'+JSON.stringify(data));
            this.categoryName=data.Name.toUpperCase();
            console.log('set to:'+this.categoryName);
            console.log('contains isuzu:'+this.categoryName.includes('ISUZU'));
            console.log('contains yanmar:'+this.categoryName.includes('YANMAR'));
        }else if(error){
            console.log('wiredProductCategory error:'+JSON.stringify(error));
        }
    }

    get trademark(){     
        console.log('categoryName:'+this.categoryName);   
        if(this.categoryName.includes('ISUZU')){
            return '* Isuzu is a registered trademark of Isuzu Jidosha Kabushiki Kaisha Corporation.';
        }else if(this.categoryName.includes('YANMAR')){
            return '* Yanmar is a registered trademark of Yanmar Co., Ltd. Corporation';
        }       
    }
}