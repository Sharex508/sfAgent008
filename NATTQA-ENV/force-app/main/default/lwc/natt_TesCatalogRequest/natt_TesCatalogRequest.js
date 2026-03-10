import { LightningElement, api, wire, track  } from 'lwc';
import CommunityId from "@salesforce/community/Id";
import userId from '@salesforce/user/Id';
import sendEmail from '@salesforce/apex/NATT_TesCatalogRequestController.sendEmailToController'

export default class Natt_TesCatalogRequest extends LightningElement {
    @api nameFieldValue;
    @api lastnameFieldValue;
    @api emailFieldValue;
    companyFieldValue;
    streetFieldValue;
    cityFieldValue;
    stateFieldValue;
    postalCodeFieldValue;
    countryFieldValue;
    stateDisabled = false;
    submitDisabled = true;
    @api label = 'State';
    @api placeholder;
    passwordErrorMessage;
    @track nameValue;
    streetValue;
    cityValue;
    stateValue;
    @track showEmailSuccessScreen = false;
    @track subject = 'Test Email'
    @track body = 'Hello'
    @track toSend = 'sales.thermoenginesupply@carrier.com'

    


    handleChange(event){
        //Cycles through the different field values and assigns them to the above variables
        if(event.target.dataset.id === 'nameField'){
            this.nameFieldValue = (event.target.value).trim();
        }else if(event.target.dataset.id === 'companyField'){
            this.companyFieldValue = (event.target.value).trim();
        }else if(event.target.dataset.id === 'emailField'){
            this.emailFieldValue = (event.target.value).trim();
        }else if(event.target.dataset.id === 'streetField'){
            this.streetFieldValue = (event.target.value).trim();
        }else if(event.target.dataset.id === 'cityField'){
            this.cityFieldValue = (event.target.value).trim();
            // if(this.cityFieldValue == null){
            //     this.submitDisabled = true;
            // }else{
            //     this.submitDisabled = false;
            // }
        }else if(event.target.dataset.id === 'postalCodeField'){
            this.postalCodeFieldValue = (event.target.value).trim();
        }else if(event.target.dataset.id === 'stateField'){
            this.stateFieldValue = (event.target.value).trim();
        }else if(event.target.dataset.id === 'countryField'){
            this.countryFieldValue = (event.target.value).trim();
            if(this.countryFieldValue != 'US' ){
                this.stateDisabled = true;
                // this.stateFieldValue = null;
            }else{
                this.stateDisabled = false;
            }
        }
        console.log('Name: ' + this.nameFieldValue);
        console.log('State: ' +  this.stateFieldValue);
        console.log('Country: ' + this.countryFieldValue);
        if(this.nameFieldValue == null || this.emailFieldValue == null || this.companyFieldValue == null || this.streetFieldValue == null || this.cityFieldValue == null || this.postalCodeFieldValue == null || this.countryFieldValue == null){
            this.submitDisabled = true;
        }else if(this.countryFieldValue == 'US' && this.stateFieldValue == null){
            this.submitDisabled = true;
        }else if(this.countryFieldValue != 'US' && this.countryFieldValue != null){
            this.stateFieldValue = null;
        }else{
            this.submitDisabled = false;
        }
    } 

    sendCatalogEmail(){
        console.log('Name: ' + this.nameValue);
        console.log('Street: ' + this.streetValue);
        console.log('City: ' + this.cityValue);
        this.subject = 'Catalog Request ' + this.nameFieldValue;
        this.body = this.nameFieldValue +  '\n'  +
            this.streetFieldValue +  '\n'  +
            this.cityFieldValue + ', ' + this.stateFieldValue +  '&nbsp;'  +
            this.postalCodeFieldValue + ' ' +  this.countryFieldValue;
        console.log('Body: ' + this.body);
        const recordInput = {name: this.nameFieldValue, company:this.companyFieldValue, email:this.emailFieldValue, street: this.streetFieldValue, city: this.cityFieldValue, state: this.stateFieldValue, postalcode: this.postalCodeFieldValue, country: this.countryFieldValue, toSend: this.toSend, subject: this.subject}

        sendEmail(recordInput)
        .then(result => {
            console.log('SUCCESS');
            this.showEmailSuccessScreen = true;
        })
        .catch(error => {
            console.log('Email FAILED send: ' + error.body.message);
            this.error = error;
            // this.priceFileList=error.body.message;            
        })   
    }


    get choices() {
        return this.states.map(s => ({ label: s[1], value: s[0] }));
    }
    get choicesCountry() {
        return this.countries.map(s => ({ label: s[1], value: s[0] }));
    }
    // get choicesCountry() {
    //     return this.countries.map(s => ({ label: s, value: s}));
    // }

    get states() {
        return [
            ['AL','Alabama'], ['AK','Alaska'], ['AZ','Arizona'], ['AR','Arkansas'], ['CA','California'], ['CO','Colorado'], ['CT','Connecticut'], 
            ['DE','Delaware'], ['DC','District of Columbia'], ['FL','Florida'], ['GA','Georgia'], ['HI','Hawaii'], ['ID','Idaho'], ['IL','Illinois'], 
            ['IN','Indiana'], ['IA','Iowa'], ['KS','Kansas'], ['KY','Kentucky'], ['LA','Louisiana'], ['ME','Maine'], ['MD','Maryland'], ['MA','Massachusetts'], 
            ['MI','Michigan'], ['MN','Minnesota'], ['MS','Mississippi'], ['MO','Missouri'], ['MT','Montana'], ['NE','Nebraska'], ['NV','Nevada'], ['NH','New Hampshire'], 
            ['NJ','New Jersey'], ['NM','New Mexico'], ['NY','New York'], ['NC','North Carolina'], ['ND','North Dakota'], ['OH','Ohio'], ['OK','Oklahoma'], ['OR','Oregon'], 
            ['PA','Pennsylvania'], ['PR','Puerto Rico'], ['RI','Rhode Island'], ['SC','South Carolina'], ['SD','South Dakota'], ['TN','Tennessee'], ['TX','Texas'], 
            ['VI','U.S. Virgin Islands'], ['UT','Utah'], ['VT','Vermont'], ['VA','Virginia'], ['WA','Washington'], ['WV','West Virginia'], ['WI','Wisconsin'], 
            ['WY','Wyoming']
        ];
    }

    get countries(){
        return [
            ['US', 'United States'], ['CA', 'Canada'],['AF', 'Afghanistan'],['AL', 'Albania'],['DZ', 'Algeria'],['AS', 'American Samoa'],['AD', 'Andorra'],['AO', 'Angola'],['AI', 'Anguilla'],
            ['AQ', 'Antarctica'],['AG', 'Antigua and Barbuda'],['AR', 'Argentina'],['AM', 'Armenia'],['AW', 'Aruba'],['AU', 'Australia'],['AT', 'Austria'],['AZ', 'Azerbaijan'],
            ['BS', 'Bahamas'],['BH', 'Bahrain'],['BD', 'Bangladesh'],['BB', 'Barbados'],['BY', 'Belarus'],['BE', 'Belgium'],['BZ', 'Belize'],['BJ', 'Benin'],['BM', 'Bermuda'],
            ['BT', 'Bhutan'],['BO', 'Bolivia, Plurinational State of'],['BQ', 'Bonaire, Sint Eustatius and Saba'],['BA', 'Bosnia and Herzegovina'],['BW', 'Botswana'],['BV', 'Bouvet Island'],
            ['BR', 'Brazil'],['IO', 'British Indian Ocean Territory'],['BN', 'Brunei Darussalam'],['BG', 'Bulgaria'],['BF', 'Burkina Faso'],['BI', 'Burundi'],['KH', 'Cambodia'],['CM', 'Cameroon'],
            ['CV', 'Cape Verde'],['KY', 'Cayman Islands'],['CF', 'Central African Republic'],['TD', 'Chad'],['CL', 'Chile'],['CN', 'China'],['CX', 'Christmas Island'],
            ['CC', 'Cocos (Keeling) Islands'],['CO', 'Colombia'],['KM', 'Comoros'],['CG', 'Congo'],['CD', 'Congo, the Democratic Republic of the'],['CK', 'Cook Islands'],['CR', 'Costa Rica'],
            ['CI', 'Cote d\'Ivoire'],['HR', 'Croatia'],['CU', 'Cuba'],['CW', 'Cura\u00e7ao'],['CY', 'Cyprus'],['CZ', 'Czech Republic'],['DK', 'Denmark'],['DJ', 'Djibouti'],['DM', 'Dominica'],
            ['DO', 'Dominican Republic'],['EC', 'Ecuador'],['EG', 'Egypt'],['SV', 'El Salvador'],['GQ', 'Equatorial Guinea'],['ER', 'Eritrea'],['EE', 'Estonia'],['ET', 'Ethiopia'],
            ['FK', 'Falkland Islands (Malvinas)'],['FO', 'Faroe Islands'],['FJ', 'Fiji'],['FI', 'Finland'],['FR', 'France'],['GF', 'French Guiana'],['PF', 'French Polynesia'],
            ['TF', 'French Southern Territories'],['GA', 'Gabon'],['GM', 'Gambia'],['GE', 'Georgia'],['DE', 'Germany'],['GH', 'Ghana'],['GI', 'Gibraltar'],['GR', 'Greece'],['GL', 'Greenland'],
            ['GD', 'Grenada'],['GP', 'Guadeloupe'],['GU', 'Guam'],['GT', 'Guatemala'],['GG', 'Guernsey'],['GN', 'Guinea'],['GW', 'Guinea-Bissau'],['GY', 'Guyana'],['HT', 'Haiti'],
            ['HM', 'Heard Island and McDonald Islands'],['VA', 'Holy See (Vatican City State)'],['HN', 'Honduras'],['HK', 'Hong Kong'],['HU', 'Hungary'],['IS', 'Iceland'],['IN', 'India'],
            ['ID', 'Indonesia'],['IR', 'Iran'],['IQ', 'Iraq'],['IE', 'Ireland'],['IM', 'Isle of Man'],['IL', 'Israel'],['IT', 'Italy'],['JM', 'Jamaica'],['JP', 'Japan'],
            ['JE', 'Jersey'],['JO', 'Jordan'],['KZ', 'Kazakhstan'],['KE', 'Kenya'],['KI', 'Kiribati'],['KP', 'Korea, Democratic People\'s Republic of'],['KR', 'Korea, Republic of'],['KW', 'Kuwait'],
            ['KG', 'Kyrgyzstan'],['LA', 'Lao People\'s Democratic Republic'],['LV', 'Latvia'],['LB', 'Lebanon'],['LS', 'Lesotho'],['LR', 'Liberia'],['LY', 'Libya'],['LI', 'Liechtenstein'],
            ['LT', 'Lithuania'],['LU', 'Luxembourg'],['MO', 'Macao'],['MK', 'Macedonia, the Former Yugoslav Republic of'],['MG', 'Madagascar'],['MW', 'Malawi'],['MY', 'Malaysia'],['MV', 'Maldives'],
            ['ML', 'Mali'],['MT', 'Malta'],['MH', 'Marshall Islands'],['MQ', 'Martinique'],['MR', 'Mauritania'],['MU', 'Mauritius'],['YT', 'Mayotte'],['MX', 'Mexico'],['FM', 'Micronesia, Federated States of'],
            ['MD', 'Moldova, Republic of'],['MC', 'Monaco'],['MN', 'Mongolia'],['ME', 'Montenegro'],['MS', 'Montserrat'],['MA', 'Morocco'],['MZ', 'Mozambique'],['MM', 'Myanmar'],['NA', 'Namibia'],
            ['NR', 'Nauru'],['NP', 'Nepal'],['NL', 'Netherlands'],['NC', 'New Caledonia'],['NZ', 'New Zealand'],['NI', 'Nicaragua'],['NE', 'Niger'],['NG', 'Nigeria'],['NU', 'Niue'],['NF', 'Norfolk Island'],
            ['MP', 'Northern Mariana Islands'],['NO', 'Norway'],['OM', 'Oman'],['PK', 'Pakistan'],['PW', 'Palau'],['PS', 'Palestine, State of'],['PA', 'Panama'],['PG', 'Papua New Guinea'],['PY', 'Paraguay'],
            ['PE', 'Peru'],['PH', 'Philippines'],['PN', 'Pitcairn'],['PL', 'Poland'],['PT', 'Portugal'],['PR', 'Puerto Rico'],['QA', 'Qatar'],['RE', 'R\u00e9union'],['RO', 'Romania'],['RU', 'Russian Federation'],
            ['RW', 'Rwanda'],['LC', 'Saint Lucia'],['PM', 'Saint Pierre and Miquelon'],['VC', 'Saint Vincent and the Grenadines'],['WS', 'Samoa'],['SM', 'San Marino'],['ST', 'Sao Tome and Principe'],['SA', 'Saudi Arabia'],['SN', 'Senegal'],['RS', 'Serbia'],
            ['SC', 'Seychelles'],['SL', 'Sierra Leone'],['SG', 'Singapore'],['SX', 'Sint Maarten (Dutch part)'],['SK', 'Slovakia'],['SI', 'Slovenia'],['SB', 'Solomon Islands'],['SO', 'Somalia'],['ZA', 'South Africa'],
            ['GS', 'South Georgia and the South Sandwich Islands'],['SS', 'South Sudan'],['ES', 'Spain'],['LK', 'Sri Lanka'],['SD', 'Sudan'],['SR', 'Suriname'],['SJ', 'Svalbard and Jan Mayen'],['SZ', 'Swaziland'],['SE', 'Sweden'],
            ['CH', 'Switzerland'],['SY', 'Syrian Arab Republic'],['TW', 'Taiwan, Province of China'],['TJ', 'Tajikistan'],['TZ', 'Tanzania, United Republic of'],['TH', 'Thailand'],['TL', 'Timor-Leste'],['TG', 'Togo'],['TK', 'Tokelau'],
            ['TO', 'Tonga'],['TT', 'Trinidad and Tobago'],['TN', 'Tunisia'],['TR', 'Turkey'],['TM', 'Turkmenistan'],['TC', 'Turks and Caicos Islands'],['TV', 'Tuvalu'],['UG', 'Uganda'],['UA', 'Ukraine'],['AE', 'United Arab Emirates'],
            ['GB', 'United Kingdom'],['UM', 'United States Minor Outlying Islands'],['UY', 'Uruguay'],['UZ', 'Uzbekistan'],['VU', 'Vanuatu'],['VE', 'Venezuela, Bolivarian Republic of'],['VN', 'Viet Nam'],
            ['VG', 'Virgin Islands, British'],['VI', 'Virgin Islands, U.S.'],['WF', 'Wallis and Futuna'],['EH', 'Western Sahara'],['YE', 'Yemen'],['ZM', 'Zambia'],['ZW', 'Zimbabwe']
        ];
    }




}