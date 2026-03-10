@IsTest
public class NAC_UserSignUpTest {
    @IsTest
    static void getAddressDetailsTest(){
      
        Account a = new Account(Name='TestNACAccount'+NAC_TestDataFactory.randomStringGenerator(),AccountNumber='234455');
        insert a;
        Account acc=[SELECT Id,Name,IsBuyer,AccountNumber from Account where AccountNumber=:a.accountNumber];
 
        Test.startTest();
        NAC_UserSignUp.userWrapper uWrap=NAC_UserSignUp.getAddressDetails(a.id);
        String s=NAC_UserSignUp.getAccountNumberDetails();
        Test.stopTest();
        System.assertNotEquals(uWrap,null,'There has been some error');
        System.assertNotEquals(s,null,'There has been some error while getting the account details');
    }
    @IsTest
     static void createContactTest(){
        Map<Object, Object> contactData=new Map<Object, Object>();
        Account acc=NAC_TestDataFactory.insertAccount();
        acc.AccountNumber='11223345';
        Update acc;
         
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc);
        contactData.put('accountNumber',acc.AccountNumber);   
        contactData.put('contactFirstName','TestCon');
        contactData.put('contactLastName','ConTest');
        contactData.put('email','TestCon@gmail.com');
        contactData.put('jobTitle','Employee');
        contactData.put('phoneNumber','1234567890');
         
        Test.startTest();
        Boolean returned=NAC_UserSignUp.createContact(contactData);
        Test.stopTest();
        System.assertNotEquals(returned,true,'There has been some error');
    }
    
    @IsTest
    static void createAccountTest(){
        Map<Object, Object> AccountData=new Map<Object, Object>();
        Account acc=NAC_TestDataFactory.insertAccount();
        acc.AccountNumber='11223345';
        Update acc;
         
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc);
        AccountData.put('legalCompanyName','TestAccount');
        AccountData.put('accountPhoneNumber','1234567890');
        AccountData.put('accountEmailAddress','TestAccount@gmail.com');
        AccountData.put('accountWebpage','hhtps://Google.com');
        AccountData.put('accountBillingStreetAddress','TestStreet');
        AccountData.put('accountBillingCity','TestBillingStreet');
        AccountData.put('accountBillingState','TestBillingState');
        AccountData.put('accountBillingZipCode','123400');
        AccountData.put('accountBillingCountry','US');
        AccountData.put('accountShippingStreetAddress','TestShipStreet');
        AccountData.put('accountShippingCity','Los Angeles');
        AccountData.put('accountShippingState','California');
        AccountData.put('accountShippingZipCode','12345678');
        AccountData.put('accountShippingCountry','US');
        //Contact Fields
        AccountData.put('contactPartsFirstName','TestConAcc');
        AccountData.put('contactPartsLastName','ConAccTest');
        AccountData.put('contactPartsEmailAddress','ConAccTest@gmail.com');
        AccountData.put('contactPartsPhoneNumber','0987654321');
        AccountData.put('contactFinanceFirstName','TestConFinance');
        AccountData.put('contactFinanceLastName','ConFinanceTest');
        AccountData.put('contactFinanceEmailAddress','TestConFinance@gmail.com');
        AccountData.put('contactFinancePhoneNumber','9879899909');
        
        Test.startTest();
        Boolean returnedof=NAC_UserSignUp.createAccount(AccountData);
        NAC_UserSignUp.fetchCountryandStates();
        Test.stopTest();
        System.assertNotEquals(returnedof,false,'There has been some error');
    }
}