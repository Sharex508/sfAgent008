import { LightningElement, api } from 'lwc';
import CommunityId from "@salesforce/community/Id";
import userId from '@salesforce/user/Id';

export default class Natt_newUserRegistration extends LightningElement {
    @api nameFieldValue;
    @api lastnameFieldValue;
    @api emailFieldValue;
    passwordFieldValue;
    password2FieldValue;
    companyFieldValue;
    telephoneFieldValue;
    streetFieldValue;
    street2FieldValue;
    cityFieldValue;
    stateFieldValue;
    postalCodeFieldValue;
    countryFieldValue;
    stateDisabled = false;
    @api label = 'State';
    @api placeholder;
    passwordErrorMessage;

    handleChange(event){
        //Cycles through the different field values and assigns them to the above variables
        if(event.target.dataset.id === 'nameField'){
            this.nameFieldValue = (event.target.value).trim();
        }else if(event.target.dataset.id === 'lastnameField'){
            this.lastnameFieldValue = (event.target.value).trim();
        }else if(event.target.dataset.id === 'emailField'){
            this.emailFieldValue = (event.target.value).trim();
        }else if(event.target.dataset.id === 'companyField'){
            this.companyFieldValue = (event.target.value).trim();
        }else if(event.target.dataset.id === 'telephoneField'){
            this.telephoneFieldValue = (event.target.value).trim();
        }else if(event.target.dataset.id === 'streetField'){
            this.streetFieldValue = (event.target.value).trim();
        }
        // else if(event.target.dataset.id === 'street2Field'){
        //     this.street2FieldValue = (event.target.value).trim();
        // }
        else if(event.target.dataset.id === 'cityField'){
            this.cityFieldValue = (event.target.value).trim();
        }else if(event.target.dataset.id === 'stateField'){
            this.stateFieldValue = event.target.value;
        }else if(event.target.dataset.id === 'postalCodeField'){
            this.postalCodeFieldValue = (event.target.value).trim();
        }else if(event.target.dataset.id === 'countryField'){
            this.countryFieldValue = event.target.value;
            if(this.countryFieldValue != 'US' ){
                this.stateDisabled = true;
                // this.stateFieldValue = null;
            }else{
                this.stateDisabled = false;
            }
        }else if(event.target.dataset.id === 'passwordField'){
            this.passwordFieldValue = (event.target.value).trim();
        }else if(event.target.dataset.id === 'password2Field'){
            this.password2FieldValue = (event.target.value).trim();
            if(this.password2FieldValue != this.passwordFieldValue){
                this.passwordErrorMessage = 'Passwords do not match';
            }else{
                this.passwordErrorMessage = null;
            }
        }
        // console.log('state: ' + this.stateFieldValue);
        // console.log('coutnry: ' + this.countryFieldValue);
        console.log('Community ID Value: ' + CommunityId);
        console.log('User Id: ' + userId);
        console.log('Country Value: ' + this.countryFieldValue);
        const evt= new CustomEvent('passuserfields', 
            {detail:{
                nameFieldValue:this.nameFieldValue,
                lastnameFieldValue:this.lastnameFieldValue,
                emailFieldValue:this.emailFieldValue,
                companyFieldValue:this.companyFieldValue,
                telephoneFieldValue:this.telephoneFieldValue,
                streetFieldValue:this.streetFieldValue,
                // street2FieldValue:this.street2FieldValue,
                cityFieldValue:this.cityFieldValue,
                stateFieldValue:this.stateFieldValue,
                postalCodeFieldValue:this.postalCodeFieldValue,
                countryFieldValue:this.countryFieldValue,
                passwordFieldValue:this.passwordFieldValue,
                password2FieldValue:this.password2FieldValue,
                communityIdValue:CommunityId,
                userIdValue:userId
            }}
        );

        // const evt= new CustomEvent('userFieldEvent', 
        //     {detail:
        //         this.nameFieldValue
        //     }
        // );

        this.dispatchEvent(evt);


    }

    // handleClick(event){
    //     console.log('name value: ' + this.nameFieldValue);
    //     console.log('email value: ' + this.emailFieldValue);
    //     console.log('company value: ' + this.companyFieldValue);
    //     console.log('telephone value: ' + this.telephoneFieldValue);
    //     console.log('street value: ' + this.streetFieldValue);
    //     console.log('street2 value: ' + this.street2FieldValue);
    //     console.log('city value: ' + this.cityFieldValue);
    //     console.log('state value: ' +this.stateFieldValue);
    //     console.log('postalCode value: ' + this.postalCodeFieldValue);
    //     console.log('country value: ' + this.countryFieldValue);
    //     const evt= new CustomEvent('userFieldEvent', 
    //         {detail:
    //             this.nameFieldValue
    //         }
    //     );

    //     this.dispatchEvent(evt);
    // }

    // get choices() {
    //     return this.states.map(s => ({ label: s, value: s.toLowerCase() }));
    // }
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
            ['US', 'United States'], ['AF', 'Afghanistan'],['AL', 'Albania'],['DZ', 'Algeria'],['AS', 'American Samoa'],['AD', 'Andorra'],['AO', 'Angola'],['AI', 'Anguilla'],
            ['AQ', 'Antarctica'],['AG', 'Antigua and Barbuda'],['AR', 'Argentina'],['AM', 'Armenia'],['AW', 'Aruba'],['AU', 'Australia'],['AT', 'Austria'],['AZ', 'Azerbaijan'],
            ['BS', 'Bahamas'],['BH', 'Bahrain'],['BD', 'Bangladesh'],['BB', 'Barbados'],['BY', 'Belarus'],['BE', 'Belgium'],['BZ', 'Belize'],['BJ', 'Benin'],['BM', 'Bermuda'],
            ['BT', 'Bhutan'],['BO', 'Bolivia, Plurinational State of'],['BQ', 'Bonaire, Sint Eustatius and Saba'],['BA', 'Bosnia and Herzegovina'],['BW', 'Botswana'],['BV', 'Bouvet Island'],
            ['BR', 'Brazil'],['IO', 'British Indian Ocean Territory'],['BN', 'Brunei Darussalam'],['BG', 'Bulgaria'],['BF', 'Burkina Faso'],['BI', 'Burundi'],['KH', 'Cambodia'],['CM', 'Cameroon'],
            ['CA', 'Canada'],['CV', 'Cape Verde'],['KY', 'Cayman Islands'],['CF', 'Central African Republic'],['TD', 'Chad'],['CL', 'Chile'],['CN', 'China'],['CX', 'Christmas Island'],
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

    handleSelect(event) {
        this.dispatchEvent(
            new CustomEvent('valueselect', {
                detail: {                
                    value: event.detail.value
                }
            })
        );
    }

    // checkPasswordStrength : function(component, helper) {
         
    //     //Get password
    //     var password = component.get("v.password");
         
    //     //Password strength
    //     let strength = {
    //         1: 'Very Weak',
    //         2: 'Weak',
    //         3: 'Medium',
    //         4: 'Strong',
    //         5: 'Very Strong'
    //     };
         
    //     //Password Strength Check
    //     let strengthValue = {
    //         'caps': false,
    //         'length': false,
    //         'special': false,
    //         'numbers': false,
    //         'small': false
    //     };
         
    //     //Password strength styles
    //     let passwordStrengthStyle = {
    //         0: 'slds-theme--error',
    //         1: 'slds-theme--error',
    //         2: 'slds-theme--warning',
    //         3: 'slds-theme--info',
    //         4: 'slds-theme--alt-inverse',
    //         5: 'slds-theme--success'
    //     };
         
    //     //Check Password Length
    //     if(password.length >= 8) {
    //         strengthValue.length = true;
    //     }
         
    //     //Calculate Password Strength
    //     for(let index=0; index < password.length; index++) {
    //         let char = password.charCodeAt(index);
    //         if(!strengthValue.caps && char >= 65 && char <= 90) {
    //             strengthValue.caps = true;
    //         } else if(!strengthValue.numbers && char >=48 && char <= 57){
    //             strengthValue.numbers = true;
    //         } else if(!strengthValue.small && char >=97 && char <= 122){
    //             strengthValue.small = true;
    //         } else if(!strengthValue.numbers && char >=48 && char <= 57){
    //             strengthValue.numbers = true;
    //         } else if(!strengthValue.special && (char >=33 && char <= 47) || (char >=58 && char <= 64)) {
    //             strengthValue.special = true;
    //         }
    //     }
         
    //     let strengthIndicator = 0;
    //     for(let metric in strengthValue) {
    //         if(strengthValue[metric] === true) {
    //             strengthIndicator++;
    //         }
    //     }
         
    //     //get badge
    //     var psBadge = component.find('psBadge');
         
    //     //Remove style
    //     for(let strengthStyle in passwordStrengthStyle) {
    //         $A.util.removeClass(psBadge, passwordStrengthStyle[strengthStyle]);
    //     }
         
    //     //Add style
    //     $A.util.addClass(psBadge, passwordStrengthStyle[strengthIndicator]);
         
    //     //set password strength
    //     component.set("v.passwordStrength", strength[strengthIndicator]);
    // }
    
}