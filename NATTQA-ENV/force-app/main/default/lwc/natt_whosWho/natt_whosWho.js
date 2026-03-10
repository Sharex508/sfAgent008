import { LightningElement, api, track, wire } from 'lwc';
import getWhosWho from '@salesforce/apex/NATT_WhoswhoController.getWhosWhoArticle';
import communityBasePath from '@salesforce/community/basePath';
import WhosWhoLink from'@salesforce/label/c.Whos_Who';
import WhosWhoErrorMessage from'@salesforce/label/c.WhosWho_ErrorMessage';

export default class Natt_whosWho extends LightningElement {

    @track showWarningMessage = false;
    @track errorMessage = '';
    @track article = {};

    label = {
        WhosWhoLink,
        WhosWhoErrorMessage
    };

    connectedCallback() {
        getWhosWho()
            .then(result => {                
                if (result.success) {

                    if (result.data.length == 0) {
                        this.showErrorMessage(this.label.WhosWhoErrorMessage);
                    } else {
                        this.article = result.data[0];
                        this.article.url = 'article/' + this.article.UrlName;
                    }
                    
                } else {
                    this.showErrorMessage(result.message);
                }

            })
            .catch(error => {
                console.log('error is: ' + JSON.stringify(error));                
            });
    
    }

    showErrorMessage(message) {
        this.showWarningMessage = true;
        this.errorMessage = message;
    }

}