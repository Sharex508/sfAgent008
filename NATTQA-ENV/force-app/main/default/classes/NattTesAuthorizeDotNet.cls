public without sharing class NattTesAuthorizeDotNet {
    private static String merchantName='95uSc9PBRp2p';
    private static String merchantTransactionkey='8m9zN4Rn6N549z39';

    private static String merchantNameProd='4Q26FwhE2v';
    private static String merchantTransactionkeyProd='5FdqLn97A9Q4c2G9';

    private static boolean isSandbox {
        get {
            if (isSandbox == null) {
                isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
            }
            return isSandbox;
        }
        set;
    }

    @AuraEnabled    
    public static AuthWrapper doAuth(String email,String amount,String cardNumber,String expirationDate,String cvv){
        AuthWrapper aw = new AuthWrapper();
        aw.hasError=false;
        String body = buildCcAuth(email,amount,cardNumber,expirationDate,cvv);
        ResponseWrapper rw = doPost(body);
        System.debug('doAuth responseBody: '+rw.returnBody);
        NattTesAuthorizeDotNetResponse authResponse = NattTesAuthorizeDotNetResponse.parse(rw.returnBody);    
        if(authResponse.transactionResponse.errors!=null && !authResponse.transactionResponse.errors.isEmpty() && String.isNotBlank(authResponse.transactionResponse.errors[0].errorText)){
            aw.hasError=true;
            aw.errorMessage=authResponse.transactionResponse.errors[0].errorText;
            return aw;
        }
        
        if(rw.statusCode==200){
            User u = [SELECT Id,ContactId,Contact.NATT_AuthorizeDotNetProfileId__c FROM User WHERE Id=:UserInfo.getUserId()];
            
            if(authResponse.transactionResponse!=null && String.isNotBlank(authResponse.transactionResponse.transId)){
                aw.transactionId = authResponse.transactionResponse.transId;
            }
            if(aw.transactionId!=null){
                //the transaction created successfully, see if a customer profile needs to be created
                rw = doProfileCreate(aw.transactionId);
                authResponse = NattTesAuthorizeDotNetResponse.parse(rw.returnBody);
                System.debug('AuthResponse: ' + authResponse);

                if(String.isNotBlank(authResponse.customerProfileId)){
                    aw.custProfileId = authResponse.customerProfileId;
                }else if(authResponse.profileResponse!=null && authResponse.profileResponse.messages!=null &&
                        authResponse.profileResponse.messages.resultCode=='Error' && String.isBlank(u.Contact.NATT_AuthorizeDotNetProfileId__c)){
                    if(authResponse.profileResponse.messages.message[0].text.contains('A duplicate record with ID ')){        
                        //if there is a duplicate error...update the profile Id on the contact
                        Pattern pat = Pattern.compile('([0-9]+)');
                        Matcher matcher = pat.matcher(authResponse.profileResponse.messages.message[0].text);
                        if(matcher.find()){
                            aw.custProfileId=matcher.group(1);
                        }                    
                    }
                }
                if(aw.custProfileId!=null){
                    //create a payment method to store for the order
                    rw = doPaymentProfileCreate(aw.custProfileId, cardNumber, expirationDate, cvv);
                    authResponse = NattTesAuthorizeDotNetResponse.parse(rw.returnBody);
                    if(authResponse.messages!=null && authResponse.messages.resultCode=='Ok'){
                        aw.paymentProfileId=authResponse.customerPaymentProfileId;
                    }else if(authResponse.messages!=null && authResponse.messages.resultCode=='Error' && authResponse.messages.message[0].text.contains('A duplicate customer payment profile already exists') && String.isNotBlank(authResponse.customerPaymentProfileId)){
                        aw.paymentProfileId=authResponse.customerPaymentProfileId;
                    }else{
                        aw.hasError=true;
                        aw.errorMessage = authResponse.messages.message[0].text;
                    }
                }
            }
            
            if(String.isNotBlank(u.ContactId) && String.isNotBlank(aw.custProfileId)){
                Contact c = new Contact(Id=u.ContactId,NATT_AuthorizeDotNetProfileId__c=aw.custProfileId);
                update c;
            }            
        }else{
            aw.hasError=true;
            aw.errorMessage = authResponse.messages.message[0].text;            
        }
        return aw;
    }

    public static ResponseWrapper doProfileCreate(String transId){
        String body = buildCreateCustomerProfileFromTransaction(transId);
        ResponseWrapper rw = doPost(body);
        return rw;        
    }

    public static ResponseWrapper doPaymentProfileCreate(String customerProfileId,String cardNumber,String expirationDate,String cvv){
        String body = buildCreateCustomerPaymentProfile(customerProfileId,cardNumber,expirationDate,cvv);
        ResponseWrapper rw = doPost(body);
        return rw;
    }

    public static ResponseWrapper doVoidTransaction(String transId){
        String body = buildVoidTransaction(transId);
        ResponseWrapper rw = doPost(body);
        return rw;
    }

    public static ResponseWrapper doChargeCustomerProfile(String customerProfileId,String paymentProfileId,Decimal amount){
        System.debug('doChargeCustomerProfile:'+customerProfileId+' paymentProfileID: '+paymentProfileId+' Amount: '+amount);
        String body = buildChargeCustomerProfile(customerProfileId, paymentProfileId, String.valueOf(amount));
        ResponseWrapper rw = doPost(body);
        System.debug('doChargeCustomerProfile responseBody: '+rw.returnBody);        
        return rw;
    }

    @future(callout=true)
    public static void processShipment(Set<Id> shipmentIdSet){
        ResponseWrapper rw;
        List<Shipment> shipmentList = new List<Shipment>();
        NattTesAuthorizeDotNetResponse authResponse;
        for(Shipment s : [SELECT Id,NATT_Transaction_Id__c,NATT_AuthorizeDotNetProfileId__c,NATT_JdeInvoiceAmount__c,NATT_Transaction_Payment_Id__c FROM Shipment WHERE Id in :shipmentIdSet]){
            //void the original transaction hold    
            System.debug('TRANSACTION ID IN PROCESSSHIP: ' + s.NATT_Transaction_Id__c);      
            rw = doVoidTransaction(s.NATT_Transaction_Id__c);
            authResponse = NattTesAuthorizeDotNetResponse.parse(rw.returnBody); 
            if(authResponse.messages!=null && authResponse.messages.resultCode=='Ok'){
                System.debug('void successful');
            }else{
                System.debug('void not successful');
            }
            //use the profile to charge the new amount
            rw = doChargeCustomerProfile(s.NATT_AuthorizeDotNetProfileId__c, s.NATT_Transaction_Payment_Id__c, s.NATT_JdeInvoiceAmount__c);
            authResponse = NattTesAuthorizeDotNetResponse.parse(rw.returnBody); 
            if(authResponse.messages!=null && authResponse.messages.resultCode=='Ok'){
                System.debug('charge successful: '+authResponse.transactionResponse.transId);
            }else{
                System.debug('charge not successful: '+authResponse.messages.message[0].text);
            }
        }
    }

    public static String buildCreateCustomerPaymentProfile(String customerProfileId,String cardNumber,String expirationDate,String cvv){
        JSONGenerator genPayPro2 = JSON.createGenerator(true);
                
        genPayPro2.writeStartObject();
        genPayPro2.writeFieldName('createCustomerPaymentProfileRequest');
        genPayPro2.writeStartObject();
        genPayPro2.writeFieldName('merchantAuthentication');
        genPayPro2.writeStartObject();
        genPayPro2.writeStringField('name', isSandbox?merchantName:merchantNameProd);
        genPayPro2.writeStringField('transactionKey', isSandbox?merchantTransactionkey:merchantTransactionkeyProd);
        genPayPro2.writeEndObject();
        genPayPro2.writeStringField('customerProfileId', customerProfileId);

        genPayPro2.writeFieldName('paymentProfile');
        genPayPro2.writeStartObject();
        
        genPayPro2.writeFieldName('payment');
        genPayPro2.writeStartObject();        
        genPayPro2.writeFieldName('creditCard');
        genPayPro2.writeStartObject();
        genPayPro2.writeStringField('cardNumber', cardNumber);
        genPayPro2.writeStringField('expirationDate', expirationDate);
        genPayPro2.writeStringField('cardCode', cvv);
        genPayPro2.writeEndObject();
        genPayPro2.writeEndObject();
        genPayPro2.writeBooleanField('defaultPaymentProfile', true);

        genPayPro2.writeEndObject();
        genPayPro2.writeEndObject();        
        
        return genPayPro2.getAsString();
    }

    private static String buildCcAuth(String email,String amount,String cardNumber,String expirationDate,String cvv){
     	JSONGenerator genPayPro2 = JSON.createGenerator(true);
                
        genPayPro2.writeStartObject();
        genPayPro2.writeFieldName('createTransactionRequest');
        genPayPro2.writeStartObject();
        genPayPro2.writeFieldName('merchantAuthentication');
        genPayPro2.writeStartObject();
        //Merchant’s unique API Login ID.
        genPayPro2.writeStringField('name', isSandbox?merchantName:merchantNameProd);
        //Merchant’s unique Transaction Key.
        genPayPro2.writeStringField('transactionKey', isSandbox?merchantTransactionkey:merchantTransactionkeyProd);
        genPayPro2.writeEndObject();
        //genPayPro2.writeStringField('refId', '123456');
        genPayPro2.writeFieldName('transactionRequest');
        genPayPro2.writeStartObject();
        genPayPro2.writeStringField('transactionType', 'authOnlyTransaction');
        genPayPro2.writeStringField('amount', amount);
        genPayPro2.writeFieldName('payment');
        genPayPro2.writeStartObject();        
        genPayPro2.writeFieldName('creditCard');
        genPayPro2.writeStartObject();
        genPayPro2.writeStringField('cardNumber', cardNumber);
        genPayPro2.writeStringField('expirationDate', expirationDate);
        genPayPro2.writeStringField('cardCode', cvv);
        genPayPro2.writeEndObject();
        genPayPro2.writeEndObject();
        
        /*genPayPro2.writeFieldName('profile');        
        genPayPro2.writeStartObject();              
        genPayPro2.writeStringField('createProfile', 'true');        
        genPayPro2.writeEndObject();*/

        genPayPro2.writeFieldName('customer');        
        genPayPro2.writeStartObject();              
        genPayPro2.writeStringField('type', 'individual');        
        genPayPro2.writeStringField('email', email);
        genPayPro2.writeEndObject();
                
        genPayPro2.writeEndObject();
        genPayPro2.writeEndObject();
        genPayPro2.writeEndObject();
        
        return genPayPro2.getAsString();
    }

    private static String buildCreateCustomerProfileFromTransaction(String transId){
        JSONGenerator genPayPro2 = JSON.createGenerator(true);
                
        genPayPro2.writeStartObject();
        genPayPro2.writeFieldName('createCustomerProfileFromTransactionRequest');
        genPayPro2.writeStartObject();
        genPayPro2.writeFieldName('merchantAuthentication');
        genPayPro2.writeStartObject();
        genPayPro2.writeStringField('name', isSandbox?merchantName:merchantNameProd);
        genPayPro2.writeStringField('transactionKey', isSandbox?merchantTransactionkey:merchantTransactionkeyProd);
        genPayPro2.writeEndObject();
        genPayPro2.writeStringField('transId', transId);
        genPayPro2.writeEndObject();
        genPayPro2.writeEndObject();        
        
        return genPayPro2.getAsString();
    }    

    private static String buildVoidTransaction(String transId){
        JSONGenerator genPayPro2 = JSON.createGenerator(true);
                
        genPayPro2.writeStartObject();
        genPayPro2.writeFieldName('createTransactionRequest');
        genPayPro2.writeStartObject();
        genPayPro2.writeFieldName('merchantAuthentication');
        genPayPro2.writeStartObject();
        genPayPro2.writeStringField('name', isSandbox?merchantName:merchantNameProd);
        genPayPro2.writeStringField('transactionKey', isSandbox?merchantTransactionkey:merchantTransactionkeyProd);
        genPayPro2.writeEndObject();
        
        genPayPro2.writeFieldName('transactionRequest');
        genPayPro2.writeStartObject();
        genPayPro2.writeStringField('transactionType', 'voidTransaction');
        genPayPro2.writeStringField('refTransId', transId);
        genPayPro2.writeEndObject();
        genPayPro2.writeEndObject();
        genPayPro2.writeEndObject();
        
        return genPayPro2.getAsString();
    }

    private static String buildChargeCustomerProfile(String customerProfileId,String paymentProfileId,String amount){
        JSONGenerator genPayPro2 = JSON.createGenerator(true);
                
        genPayPro2.writeStartObject();
        genPayPro2.writeFieldName('createTransactionRequest');
        genPayPro2.writeStartObject();
        genPayPro2.writeFieldName('merchantAuthentication');
        genPayPro2.writeStartObject();
        genPayPro2.writeStringField('name', isSandbox?merchantName:merchantNameProd);
        genPayPro2.writeStringField('transactionKey', isSandbox?merchantTransactionkey:merchantTransactionkeyProd);
        genPayPro2.writeEndObject();

        genPayPro2.writeStringField('refId', '123456');

        genPayPro2.writeFieldName('transactionRequest');
        genPayPro2.writeStartObject();
        genPayPro2.writeStringField('transactionType', 'authCaptureTransaction');
        genPayPro2.writeStringField('amount', amount);
         
        genPayPro2.writeFieldName('profile');        
        genPayPro2.writeStartObject();
        genPayPro2.writeStringField('customerProfileId', customerProfileId);
        
        genPayPro2.writeFieldName('paymentProfile');        
        genPayPro2.writeStartObject();
        genPayPro2.writeStringField('paymentProfileId', paymentProfileId);
        genPayPro2.writeEndObject();
        genPayPro2.writeEndObject();
        
        genPayPro2.writeEndObject();
        genPayPro2.writeEndObject();
        genPayPro2.writeEndObject();

        System.debug('buildChargeCustomerProfile: '+genPayPro2.getAsString());
        
        return genPayPro2.getAsString();
    }

    private static String buildCcCapture(String amount){
       JSONGenerator genPayPro2 = JSON.createGenerator(true);
               
       genPayPro2.writeStartObject();
       genPayPro2.writeFieldName('createTransactionRequest');
       genPayPro2.writeStartObject();
       genPayPro2.writeFieldName('merchantAuthentication');
       genPayPro2.writeStartObject();
       genPayPro2.writeStringField('name', isSandbox?merchantName:merchantNameProd);
       genPayPro2.writeStringField('transactionKey', isSandbox?merchantTransactionkey:merchantTransactionkeyProd);
       genPayPro2.writeEndObject();
       genPayPro2.writeStringField('refId', '123456');
       genPayPro2.writeFieldName('transactionRequest');
       genPayPro2.writeStartObject();
       genPayPro2.writeStringField('transactionType', 'authCaptureTransaction');
       genPayPro2.writeStringField('amount', amount);
       genPayPro2.writeFieldName('payment');
       genPayPro2.writeStartObject();        
       genPayPro2.writeFieldName('creditCard');
       genPayPro2.writeStartObject();
       genPayPro2.writeStringField('cardNumber', '5424000000000015');
       genPayPro2.writeStringField('expirationDate', '2025-12');
       genPayPro2.writeStringField('cardCode', '999');
       genPayPro2.writeEndObject();
       genPayPro2.writeEndObject();
       genPayPro2.writeEndObject();
       genPayPro2.writeEndObject();
       genPayPro2.writeEndObject();
       
       return genPayPro2.getAsString();
   }

   private static ResponseWrapper doPost(String body){
        Http http1 = new Http();
        HttpRequest req = new HttpRequest();    
        Organization org = [SELECT Id,IsSandbox FROM Organization limit 1];
        if(org.IsSandbox){  
            req.setEndpoint('callout:authorizeDotNetSandbox');
        }else{
            req.setEndpoint('callout:authorizeDotNet');
        }
        req.setHeader('Content-Type','application/json');
        req.setMethod('POST'); 
        req.setBody(body);
        
        HttpResponse res = http1.send(req);
        system.debug('res1==>' +res);
        system.debug('res1==>' +res.getBody());
        String returnCorrected = res.getBody().trim().replace('\uFEFF', '');
        ResponseWrapper rw = new ResponseWrapper();
        rw.statusCode=res.getStatusCode();
        rw.returnBody=returnCorrected;
        
        return rw;
    }

    public class ResponseWrapper{
        public String returnBody {get;set;}
        public Integer statusCode {get;set;}
    }

    /*@AuraEnabled    
    public static String doAuthOrCapture(boolean authOnly,String amount,String cardNumber,String expirationDate,String cvv){
        String body;
        if(authOnly)
            body = buildCcAuth(amount,cardNumber,expirationDate,cvv);
        else{
            body = buildCcCapture(amount);
        }
        NattTesAuthorizeDotNetResponse res = doPost(body);
        if(res.httpStatusCode==200){             
            return res.transactionResponse.transId;
        }else{
            return res.messages.message[0].text;
        }
    }*/

    public class AuthWrapper{
        @AuraEnabled
        public String custProfileId {get;set;}
        @AuraEnabled
        public String transactionId {get;set;}
        @AuraEnabled
        public String paymentProfileId {get;set;}
        @AuraEnabled
        public String errorMessage {get;set;}
        @AuraEnabled
        public boolean hasError {get;set;}       
    }
}