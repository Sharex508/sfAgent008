({
    onInit: function (component, event, helper){ 
        document.addEventListener("grecaptchaVerified", function(e) {
            component.set('v.recaptchaResponse', e.detail.response);
            console.log('onInit Respose Value: ' + e.detail.response);
            let myButton = component.find("myButton");
            myButton.set('v.disabled', false);  
            // component.find("natt_PasswordReset").receiveData(e.detail.response);

            var action = component.get("c.validateButton");
            action.setParams({
                // record: null, //TODO: map UI fields to sobject
                recaptchaResponse: component.get('v.recaptchaResponse')
            });
            
            action.setCallback(this, function(response) {
                // myButton.set('v.disabled', false);  
                //document.dispatchEvent(new Event("grecaptchaReset"));
                let myButton = component.find("myButton");
                var state = response.getState();
                // component.find("natt_PasswordReset").receiveData(e.detail.response);
                if (state === "SUCCESS") {
                    // myButton.set('v.disabled', false);  
                    var result = response.getReturnValue();
                    //alert(result);
                    //component.find("natt_PasswordReset").receiveData(result);
                } else {
                    myButton.set('v.disabled', true);
                    var errors = response.getError();
                    if (errors) {
                        console.log(errors[0]);
                    }
                }
            });
            $A.enqueueAction(action);
        });
        
        document.addEventListener("grecaptchaExpired", function() {
            let myButton = component.find("myButton");
            myButton.set('v.disabled', true);
        }); 
    },
    onRender: function (component, event, helper){ 
        document.dispatchEvent(new CustomEvent("grecaptchaRender", { "detail" : { element: 'recaptchaCheckbox'} }));
    },

    //kicks off the Account, User, Contact creation process
    //Account is created first, then a flow is called that creates the related Buyer Account (to make Account Buyer) & NATT Address
    //Once flow creates those, it returns the newly created Account Id to apex that will then create the portal user & related contact for the site
    doSubmit: function (component, event, helper){
        component.set("v.showLoadingSpinner",true);
        let errorMessage = null;
        let errorTitle = null;
        let nameValue = component.get("v.nameValue");
        let lastnameValue = component.get("v.lastnameValue");
        let emailValue = component.get("v.emailValue");
        let password1Value = component.get("v.passwordValue");
        let password2Value = component.get("v.password2Value");
        let companyValue = component.get("v.companyValue");
        let phoneValue = component.get("v.telephoneValue");
        let street1Value = component.get("v.streetValue");
        let street2Value = component.get("v.street2Value");
        let cityValue = component.get("v.cityValue");
        let stateValue = component.get("v.stateValue");
        let postalCodeValue = component.get("v.postalCodeValue");
        let countryValue = component.get("v.countryValue");
        let communityId = component.get("v.communityIdValue");
        let userId = component.get("v.userIdValue");
        let newAccountId = component.get("v.customerAccountId");
        //Set of checks to make sure user entered values into fields. Displays Notice if required value is missing
        if((nameValue == null || nameValue == "") || (lastnameValue == null || lastnameValue == "")){
            console.log('name error');
            errorTitle = 'Name not found.';
            errorMessage = 'Please enter name to continue.';
            helper.showNoticeMethod(component, errorTitle, errorMessage);
            component.set("v.showLoadingSpinner",false);
            return;
        } else if (emailValue == null || emailValue == ""){
            console.log('email address error');
            errorTitle = 'Email not found.';
            errorMessage = 'Email has not been entered. Please enter an email address to continue.';
            helper.showNoticeMethod(component, errorTitle, errorMessage);
            component.set("v.showLoadingSpinner",false);
            return;
        } else if (password1Value != password2Value || password1Value == null || password2Value == null){
            errorTitle = 'Passwords do not match.';
            errorMessage = 'Passwords do not match. Please try again.';
            helper.showNoticeMethod(component, errorTitle, errorMessage);
            component.set("v.showLoadingSpinner",false);
            return;
        } else if (street1Value == null || street1Value == ""){
            errorTitle = 'Street Address not found.';
            errorMessage = 'Please enter a street address and try again.';
            helper.showNoticeMethod(component, errorTitle, errorMessage);
            component.set("v.showLoadingSpinner",false);
            return;
        } else if (cityValue == null || cityValue == ""){
            errorTitle = 'City not found.';
            errorMessage = 'Please enter a city value.';
            helper.showNoticeMethod(component, errorTitle, errorMessage);
            component.set("v.showLoadingSpinner",false);
            return;
        }  else if (countryValue == null || countryValue == ""){
            errorTitle = 'Country not selected.';
            errorMessage = 'Please select a Country value.';
            helper.showNoticeMethod(component, errorTitle, errorMessage);
            component.set("v.showLoadingSpinner",false);
            return;
        }
        console.log('submit continued past password & email');

        var action = component.get("c.createPortalUser");
        action.setParams({
            accountId: newAccountId,
            userId : userId,
            communityId : communityId,
            customerName : nameValue,
            customerLastName : lastnameValue,
            password : password1Value,
            email : emailValue,
            company : companyValue,
            phone : phoneValue,
            street : street1Value,
            city : cityValue,
            state : stateValue,
            postalCode : postalCodeValue,
            country : countryValue
        });
        action.setCallback(this, function(response) {
            
            var state = response.getState();
            var responseValue = response.getReturnValue();
            console.log("State Value: " + state);
            if(state == 'SUCCESS'){
                component.set("v.showLoadingSpinner",false);
                //checks to see if email exists, if so, return email exists error message
                if(response.getReturnValue() == 'EMAIL'){
                    console.log('Response is Email');
                    helper.toastMessageMethod(component, 'Test');
                    component.find('notifLib').showNotice({
                        "variant": "warning",
                        "header": "Email in use.",
                        "message": "An Account with the entered Email address has already been registered. Please use a different email.",
                    });
                    return;
                }
                console.log('end success process');
                component.set("v.showInputFields",false);
                // helper.gotoURL(component);
            } else if (state == 'ERROR') {
                component.set("v.showLoadingSpinner",false);
                console.log('toast start');
                const errorMsg = response.getError()[0];
                console.log('toast fired');
                var errors = response.getError();  
                console.log('Errors Value: ' + errors);                     
                // component.set("v.showError",true);
                
                component.set("v.errorMessage",errors[0].message);
                component.find('notifLib').showNotice({
                    "variant": "error",
                    "header": "ERROR.",
                    "message": "Check fields to make sure values are entered correctly.",
                });
                console.log('ERROR SENT');
            }
        });
        $A.enqueueAction(action);
    },

    //method to recieve data from LWC portion of this component
    getValueFromLWC : function(component, event, helper)
	{
        console.log('LWC Value in AURA START');
        // const nameValue = event.getParam('nameFieldValue');
        component.set("v.nameValue",event.getParam('nameFieldValue'));
        component.set("v.lastnameValue", event.getParam('lastnameFieldValue'));
        component.set("v.emailValue",event.getParam('emailFieldValue'));
        component.set("v.companyValue",event.getParam('companyFieldValue'));
        component.set("v.telephoneValue",event.getParam('telephoneFieldValue'));
        component.set("v.streetValue",event.getParam('streetFieldValue'));
        component.set("v.street2Value",event.getParam('street2FieldValue'));        
        component.set("v.cityValue",event.getParam('cityFieldValue'));
        component.set("v.stateValue",event.getParam('stateFieldValue'));
        component.set("v.postalCodeValue",event.getParam('postalCodeFieldValue'));
        component.set("v.countryValue",event.getParam('countryFieldValue'));
        component.set("v.communityIdValue",event.getParam('communityIdValue'));
        component.set("v.userIdValue", event.getParam('userIdValue'));

        component.set("v.passwordValue",event.getParam('passwordFieldValue'));
        component.set("v.password2Value",event.getParam('password2FieldValue'));

        console.log("Name from LWC1: " + passwordValue);
        console.log("Name from LWC2: " + password2Value);
        console.log("User Id from LWC: " +userId );
	},

    lwcValueCheck : function(component, event, helper)
	{
        console.log("Name from LWC: " + event.getParam('nameFieldValue'));
    },

    returnToLogin : function(component, event, helper) {
        helper.gotoURL(component);
    },
})