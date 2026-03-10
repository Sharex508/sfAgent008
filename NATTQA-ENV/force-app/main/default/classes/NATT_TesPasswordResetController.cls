public without sharing class NATT_TesPasswordResetController {

    // private static String recaptchaSecretKey = '6LfWI54dAAAAAKA_wLlRW-EJpbx5_Ge9u5AMmBog';   //checkbox
    // private static String recaptchaSecretKey = '6LeC02YeAAAAAJV5GFW6-31ubtB86UgOj6zb24sV';  //invisible
    private static String recaptchaSecretKey = '6Lf9FqMfAAAAALtf22blVeUDyWVQHGQG2iRp1bV7';  //Kurt's Key
    
    @AuraEnabled
    public static String insertRecord(SObject record, String recaptchaResponse){
        //https://developers.google.com/recaptcha/docs/verify
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://www.google.com/recaptcha/api/siteverify');
        request.setMethod('POST');
        request.setBody('secret=' + recaptchaSecretKey + '&response=' + recaptchaResponse);
        HttpResponse response = http.send(request);
        System.debug('$$$ Response Value: ' + response);
        if (response.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            if (result.containsKey('success') && result.get('success') == true) {
                // if (result.containsKey('score')) {
                //     //score logic is only needed/returned for v3 (0.0 - 1.0)
                //     //https://developers.google.com/recaptcha/docs/v3
                //     //TODO: verify action name for the request
                //     String action = (String)result.get('action');
                //     //TODO: get threshold configuration for each action
                //     Decimal threshold = .4;
                //     Decimal score = (Decimal)result.get('score');
                //     if (score > threshold) {
                //         //TODO: perform action on record
                        
                //         return 'Success - v3';
                //     }
                // } else {
                //     //TODO: perform action on record
                    
                    return 'Success - v2';
                
            } else {
                return 'Invalid Verification';
            }
        }
        //consider letting this through
        return 'Invalid Verification Request';
    }
    

    @AuraEnabled
    public static String validateButton(String recaptchaResponse){
        //https://developers.google.com/recaptcha/docs/verify
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://www.google.com/recaptcha/api/siteverify');
        request.setMethod('POST');
        request.setBody('secret=' + recaptchaSecretKey + '&response=' + recaptchaResponse);
        HttpResponse response = http.send(request);
        if (response.getStatusCode() == 200) {
            System.debug('body response: ' + response.getBody());
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            System.debug('REsult Contains Key: ' +result.containsKey('success') );
            System.debug('REsult Get: ' + result.get('success') );
            if (result.containsKey('success') && result.get('success') == true) {
                // if (result.containsKey('score')) {
                //     //score logic is only needed/returned for v3 (0.0 - 1.0)
                //     //https://developers.google.com/recaptcha/docs/v3
                //     //TODO: verify action name for the request
                //     String action = (String)result.get('action');
                //     //TODO: get threshold configuration for each action
                //     Decimal threshold = .4;
                //     Decimal score = (Decimal)result.get('score');
                //     if (score > threshold) {
                //         //TODO: perform action on record
                        
                //         return 'Success - v3';
                //     }
                // } else {
                    //TODO: perform action on record
                    
                    return 'Success - v2';
                
            } else {
                return 'Invalid Verification';
            }
        }
        //consider letting this through
        return 'Invalid Verification Request';
    }

    @AuraEnabled
    public static Boolean resetPassword(String emailAddress){
        Boolean resetSuccess = false;
        System.debug('Email Address: ' + emailAddress);
        //User currentUser = [SELECT Id, Email FROM User WHERE Email = :emailAddress];
        List<User> users = [SELECT Id, Username FROM User WHERE Username = :emailAddress];
        System.debug('Users Value: ' + users);

        if(users != null){
            for(User u : users){
                //For reset User password
                System.resetPassword(u.Id, true);
                
                //For set User password
                //System.setPassword(u.Id, 'Test@1234');
                resetSuccess = true;
            }
        }
        return resetSuccess;
    }
}