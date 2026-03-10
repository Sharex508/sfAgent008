public with sharing class NATT_DataFactory {
    
    // ACCOUNT METHODS
    public static Account createSimpleAccount() {
        Account newAccount = new Account(
            Name = 'Account For Test',
            NATT_Status__c = NATT_Constants.ACCOUNT_ACTIVE
        );        
        Insert newAccount;
        
        Contact dealerPrincipal = createSimpleContact(newAccount.Id);
        newAccount.NATT_Dealer_Principal__c = dealerPrincipal.Id;
        
        return newAccount;
    }
    
    public static Account createAccountWithParent(String parentId) {
        if (parentId == null) {
            Account parentAccount = createSimpleAccount();
            Insert parentAccount;
            
            parentId = parentAccount.Id;
        }
        
        Account newAccount = new Account(Name = 'Account With Parent For Test', ParentId = parentId, NATT_Status__c = NATT_Constants.ACCOUNT_ACTIVE);        
        Insert newAccount;
        
        Contact dealerPrincipal = createSimpleContact(newAccount.Id);
        
        newAccount.NATT_Dealer_Principal__c = dealerPrincipal.Id;
        update newAccount;
        
        return newAccount;
    }
    
    public static Account createAccountWithName(String name) {
        Account newAccount = new Account(
            Name = name,
            NATT_Status__c = NATT_Constants.ACCOUNT_ACTIVE
        );        
        Insert newAccount;
        
        Contact dealerPrincipal = createSimpleContact(newAccount.Id);
        newAccount.NATT_Dealer_Principal__c = dealerPrincipal.Id;
        
        return newAccount;
    }
    
    // CONTACT METHODS
    
    public static Contact createSimpleContact(Id accId) {
        Contact ctc = new Contact(
            LastName = 'Contact For Test',
            NATT_Key_Business_Role__c = 'Principal',
            AccountId = accId
        );
        
        Insert ctc;
        return ctc;
    }
    
    // NATT ADDRESS METHODS
    
    public static NATT_Address__c createNATTAddress(Account acc, String type, String jdeAlpha) {
        NATT_Address__c addr = new NATT_Address__c();
        
        addr.Name = 'NATT Address Test';
        addr.NATT_Account__c = acc.Id;
        addr.NATT_Country__c = 'US';
        addr.NATT_City__c = 'Almada';
        addr.NATT_State_Province__c = 'AL';
        addr.NATT_JDE_Alpha_Name__c =  String.isNotBlank(jdeAlpha) ? jdeAlpha : '';
        addr.NATT_Type__c = type;
        addr.recordTypeId = Schema.SObjectType.NATT_Address__c.getRecordTypeInfosByDeveloperName().get('NATT_Address').getRecordTypeId();
        
        Insert addr;
        return addr;
    }
    
    // NATT ALERTS METHODS
    
    public static NATT_Alert__c createNATTAlert() {
        NATT_Alert__c obj = new NATT_Alert__c();
        
        Date today = System.today();
        
        obj.Name = 'NATT Alert Test';
        obj.NATT_AlertText__c = 'Alert text';
        obj.NATT_Start_Date__c = today;
        obj.NATT_End_Date__c = today.addDays(7);
        
        Insert obj;
        return obj;
    }
    
    // ORDER METHODS
    
    /*public static Order createSimpleOrder() {
        Order newOrder = new Order(
            Name = 'Order Test 1',
            NATT_Order_Status__c = NATT_Constants.ORDER_STATUS_COMPLETE_OR_CANCELLED.get(0),
            RecordTypeId = Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get(NATT_Constants.ORDER_NATT_UNIT_RT).getRecordTypeId(),
            EffectiveDate = System.today(),
            OrderedDate = System.today().addDays(5),
            AccountId = createSimpleAccount().Id,
            Status = 'Draft'
        );
        
        Insert newOrder;
        return newOrder;
    }
    
    public static Order createOrderWithValues(Map<String, Object> params) {
        Order newOrder = new Order(
            Name = 'Order Test 1',
            NATT_Order_Status__c = String.valueOf(params.get('NATT_Order_Status__c')),
            RecordTypeId = Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get(NATT_Constants.ORDER_NATT_UNIT_RT).getRecordTypeId(),
            EffectiveDate = System.today(),
            OrderedDate = Date.valueOf(params.get('OrderedDate')),
            AccountId = String.valueOf(params.get('AccountId')),
            OrderReferenceNumber = String.valueOf(params.get('OrderReferenceNumber')),
            PoNumber = String.valueOf(params.get('PoNumber')),
            Status = 'Draft'
        );
        
        Insert newOrder;
        return newOrder;
    } */
    
    //DS
    public static Account accRecord(){
        Id dealerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId();          
        Account acc = new Account(
            Name = 'Test Account1',
            recordTypeID = dealerRecordTypeId,
            AccountNumber = '4578');
        
        return acc;
    }
    
    public static Contact conRecord(string accID){
        
        Id RECTYPE_NATT_DEALER = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NATT_Dealer').getRecordTypeId();        
        Contact con = new Contact(
            firstName = 'TestContact',
            lastName = 'Con',
            recordTypeId = RECTYPE_NATT_DEALER,
            accountID = accID);
        
        return con;
    }
}