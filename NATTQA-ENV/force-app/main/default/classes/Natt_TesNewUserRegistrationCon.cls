public without sharing class Natt_TesNewUserRegistrationCon {
    
        /**
         * Captcha Keys obtained from Google Account. Make sure the correct key is obtained (i.e. invisible instead of checkbox)
         * If you change the key value here, the Key values will need to be changed in the Headder markup of the Community as well
         */
        // private static String recaptchaSecretKey = '6LfWI54dAAAAAKA_wLlRW-EJpbx5_Ge9u5AMmBog';   //checkbox
        // private static String recaptchaSecretKey = '6LeC02YeAAAAAJV5GFW6-31ubtB86UgOj6zb24sV';  //invisible
        // private static String recaptchaSecretKey = '6Lf9FqMfAAAAALtf22blVeUDyWVQHGQG2iRp1bV7';  //Kurt's Key
        private static String recaptchaSecretKey = '6LdwZqIfAAAAACAF4otCeVGjP3MWVTZNcHdCRvtV';  //Test Key
        //Method used to validate captcha request
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
                        return 'Success - v2';
                    
                } else {
                    return 'Invalid Verification';
                }
            }
            //consider letting this through
            return 'Invalid Verification Request';
        }
    
         /**
     * Method used to create the Portal User. Grabs the values from the input fields & creates an Account, Buyer Account, & User
     */
    @AuraEnabled
    public static String createPortalUser(String userId, String communityId, String customerName, String customerLastName, String password, String email, String company, String phone, String street, String city, String state, String postalCode, String country ){
        List<User> userEmailCheck = [SELECT Email FROM User WHERE Email = :email];
        System.debug('UserEmailCheck SIze: ' + userEmailCheck.size());
        if(userEmailCheck.size() != 0){
            System.debug('Return EMAIL');
            return 'EMAIL';
        }
        String companyName = createCompanyName(company, customerName, customerLastName);
        Account customerAccount = new Account(
            Name = companyName,
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId(),
            BillingStreet = street,
            BillingCity = city,
            BillingState = state,
            BillingPostalCode = postalCode,
            BillingCountry = country,
            Phone = phone,
            NATT_Parts_BU__c = '3713'
            );
        insert customerAccount;     
        NATT_Address__c billingAddress = new NATT_Address__c(
            NATT_Account__c = customerAccount.Id,
            NATT_Street__c = street,
            NATT_City__c = city,
            NATT_State_Province__c = state,
            NATT_Zip_Postal_Code__c = postalCode,
            NATT_Country__c = country,
            NATT_Type__c = 'Billing',
            Name = 'Billing - ' + companyName + ' ' + city + ' - ' + state
        );
        insert billingAddress;
        //Assign's New NATT Address to Account to be used in Checkout process
        customerAccount.NATT_Address_Billing__c = billingAddress.Id;
        update customerAccount; 
        BuyerAccount customerBuyerAccount = new BuyerAccount(
            BuyerId = customerAccount.Id,
            isActive = true,
            Name = companyName
        );
        insert customerBuyerAccount;
        assignBuyerGroup(customerAccount.Id);
        Datetime dt =  Datetime.now();
        Integer ms = dt.millisecond();
        String nickname = customerName + customerLastName;
        if(nickname.length() > 40){
            nickname = nickname.substring(0,35);
        }
        nickname += ms;
        String alias = customerName.substring(0,1);
        System.debug('Nickname Post: ' + nickname);
        if(customerLastName.length() < 7){
            alias += customerLastName;
        }else{
            alias += customerLastName.substring(0,7);
        }
        SYstem.debug('AccountId: ' + customerAccount.Id);
        User customerUser = new User(
            FirstName = customerName,
            LastName = customerLastName,
            Alias = alias,
            Email = email,
            UserName =  email,
            CommunityNickname = nickname
        );
        if(Test.isRunningTest()){
        }else{
            try{
                Site.createPortalUser(customerUser, customerAccount.Id, password);
                User newUser = [SELECT Id, Username FROM User WHERE Email = :email];
                assignPermissions(newUser.Id);
            } catch(DmlException e) {
                System.debug('An unexpected error has occurred: ' + e.getMessage());
                throw new AuraHandledException(e.getMessage()); 
            }
        }
         
        return 'SUCCESS';
    }
    
        /**
         * Method that creates a Comapny name from the User Inputs
         * Appends a number to the Company field if it already exists 
         * Will create a Company Name from First & Last name if no Company value was inserted
         */
        public static String createCompanyName(String company, String customerName, String customerLastName){
            String companyName = null;
            if(company != null){
                companyName = company;
            }else{
                companyName = customerName + customerLastName;
            }
            List<Account> accountNameCheck = [SELECT Name FROM Account WHERE Name = :companyName];
            //If size is greater than 0, it means this name has been used before, so add number to name to allow for creation
            if(accountNameCheck.size() > 0){
                Integer size = accountNameCheck.size() + 1;
                companyName += ' - ' + size;
            }
            System.debug('CompanyName: ' + companyName);
            return companyName;
        }
    
        /**
         * Assign necessary permissions to the new Portal User to allow access to the Store
         */
        @future
        public static void assignPermissions(String userId){        
            List<PermissionSetAssignment> psaList = new List<PermissionSetAssignment>();
            for(PermissionSet ps : [SELECT Id FROM PermissionSet WHERE Name IN ('B2B_Commerce_Buyer','B2BBuyer')]){
                psaList.add(new PermissionSetAssignment(PermissionSetId = ps.Id, AssigneeId = userId));
            }
            insert psaList;
        }
    
        /**
         * Assign necessary Buyer Group to the new Portal User to allow access to the Store
         */
        @future
        public static void assignBuyerGroup(String accountId){
            BuyerGroup tesBuyerGroup = [SELECT ID FROM BuyerGroup WHERE Name = 'TES Storefront Buyer Group'];
            BuyerGroupMember bm = new BuyerGroupMember();
            bm.buyerId = accountId;
            bm.BuyerGroupId = tesBuyerGroup.id;
            insert bm;
        }
    
    }