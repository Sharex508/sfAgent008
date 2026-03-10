@isTest
public class NATT_TesCatalogRequestControllerTest {
    @IsTest
    public static void getPaymentOptionList_Test(){
        String name = 'Test Name';
        String company = 'Test Company';
        String email = 'test@gmail.com';
        String street = '123 Street';
        String city = 'Boulder';
        String state = 'NY';
        String postalcode = '10032';
        String country = 'US';
        String toSend = 'test@cgi.com';
        String subject = 'Test Email';
        Test.startTest();        
        NATT_TesCatalogRequestController.sendEmailToController(name, company, email, street, city, state, postalcode, country, toSend, subject);
        Test.stopTest();
    }

}