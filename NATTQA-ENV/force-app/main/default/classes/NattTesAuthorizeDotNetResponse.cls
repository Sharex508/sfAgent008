public with sharing class NattTesAuthorizeDotNetResponse {
    @AuraEnabled
    public TransactionResponse transactionResponse;    
   
    @AuraEnabled
    public String refId;  

    @AuraEnabled
    public ProfileResponse profileResponse;
    
    @AuraEnabled
    public Messages_Z messages;

    @AuraEnabled
    public integer httpStatusCode;

    @AuraEnabled
    public String customerProfileId;

    @AuraEnabled
    public String customerPaymentProfileId;
    
    @AuraEnabled
    public List<String> customerProfileIdList;

    public class Messages {
        @AuraEnabled
        public String code;
        @AuraEnabled
        public String description;
    }
    
    public class ProfileResponse {       
        @AuraEnabled
        public Messages_Z messages;
        @AuraEnabled
        public String customerProfileId;
        @AuraEnabled
        public List<String> customerPaymentProfileIdList;
    }
    
    public class UserFields {       
        @AuraEnabled 
        public String name;        
        @AuraEnabled
        public String value;
    }

    public class TransactionResponse {       
        @AuraEnabled
        public String responseCode;
        @AuraEnabled
        public String authCode;
        @AuraEnabled
        public String avsResultCode;
        @AuraEnabled
        public String cvvResultCode;
        @AuraEnabled
        public String cavvResultCode;
        @AuraEnabled
        public String transId;
        @AuraEnabled
        public String refTransID;
        @AuraEnabled
        public String transHash;
        @AuraEnabled
        public String accountNumber;
        @AuraEnabled
        public String accountType;
        @AuraEnabled
        public List<Messages> messages;
        @AuraEnabled
        public List<UserFields> userFields;
        @AuraEnabled
        public String networkTransId;
        @AuraEnabled
        public List<ErrorResponse> errors;
    }    

    public class Messages_Z {
        @AuraEnabled
        public String resultCode;
        @AuraEnabled
        public List<Message> message;
    }

    public class ErrorResponse {
        @AuraEnabled
        public String errorCode;
        @AuraEnabled
        public String errorText;
    }

    public class Message {
        @AuraEnabled
        public String code;
        @AuraEnabled
        public String text;
    }

    public static NattTesAuthorizeDotNetResponse parse(String json) {
        System.debug('calledParseWith:'+json);
        NattTesAuthorizeDotNetResponse res = (NattTesAuthorizeDotNetResponse) System.JSON.deserialize(json, NattTesAuthorizeDotNetResponse.class);
        System.debug(res.refId);
        return res;
    }

}