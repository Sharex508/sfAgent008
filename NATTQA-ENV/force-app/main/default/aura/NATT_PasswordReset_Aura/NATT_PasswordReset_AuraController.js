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
    doSubmit: function (component, event, helper){
        let emailValue = component.get("v.emailValue");
        // let emailValue = component.find('email');
        if (emailValue == null || emailValue == ""){
            var toastEvent = $A.get("e.force:showToast");
            toastEvent.setParams({
                "title": "Error!",
                "message": "Please enter an email address to continue.",
                "type": "error"
            });
            toastEvent.fire();
            return;
        }
        let canSubmit = true;
        console.log('email Value: ' + emailValue);
        var action = component.get("c.resetPassword");
            action.setParams({
                emailAddress: emailValue
            });
            action.setCallback(this, function(response) {                
                var state = response.getReturnValue();
                if (state === true){
                    component.set("v.passwordSubmitReturn", "");
                    console.log('Password Reset Email Sent');
                    // alert('Password Reset Email Sent');
                    // var toastEvent = $A.get("e.force:showToast");
                    // toastEvent.setParams({
                    //     "title": "Success!",
                    //     "message": "Password Reset Email Sent",
                    //     "type": "success"
                    // });
                    // toastEvent.fire();
                    // component.find('notifLib').showNotice({
                    //     "variant": "warning",
                    //     "header": "Email in use.",
                    //     "message": "An Account with the entered Email address has already been registered. Please use a different email.",
                    // });
                    component.find('notifLib').showNotice({
                        "variant": "Success",
                        "header": "Success",
                        "message": "Please check your email. An email has been sent with instructions on how to reset your password.",
                    });
                    component.set("v.showInputFields",false);

                } else if (state === false){
                    console.log('No User was found with that Email. Try again.');
                    // component.set("v.passwordSubmitReturn", 'No User was found with that email address. Please try again.');
                    // var toastEvent = $A.get("e.force:showToast");
                    // toastEvent.setParams({
                    //     "title": "Error!",
                    //     "message": "No User was found with that email address. Please try a different email address.",
                    //     "type": "error"
                    // });
                    // toastEvent.fire();
                    // toastEvent.fire();
                    component.find('notifLib').showNotice({
                        "variant": "warning",
                        "header": "No User Found.",
                        "message": "No User found with that email address. Please try again.",
                    });
                } else {
                    var errors = response.getError();
                    if (errors) {
                        console.log(errors[0]);
                    }
                }
            });
            
        $A.enqueueAction(action);
    },

    returnToLogin : function(component, event, helper) {
        helper.gotoURL(component);
    },

})