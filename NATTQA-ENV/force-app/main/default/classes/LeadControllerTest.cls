@isTest
public class LeadControllerTest {
    
    public static testMethod void testcase_1() 
    {
        Integration__c integr = new Integration__c();
        integr.Name = 'SendLead';
        integr.Endpoint__c = 'callout:NAMED_CREDENTIAL/services/data/v37.0/sobjects/Lead/';
        integr.Method__c = 'POST';
        integr.Timeout__c = '12000';
        integr.Content_Type__c = 'application/json';
        insert integr;
         
        Integration__c integr2 = new Integration__c();
        integr2.Name = 'DevSmart_QueryLead';
        integr2.Endpoint__c = 'callout:Salesforce_DevSmart/services/data/v37.0/query?q=';
        integr2.Method__c = 'GET';
        integr2.Timeout__c = '12000';
        integr2.Content_Type__c = 'application/json';
        insert integr2;
        
        Integration__c integr3 = new Integration__c();
        integr3.Name = 'QueryExternalData';
        integr3.Endpoint__c = 'callout:NAMED_CREDENTIAL/services/data/v37.0/query?q=';
        integr3.Method__c = 'GET';
        integr3.Timeout__c = '12000';
        integr3.Content_Type__c = 'application/json';
        insert integr3;
        
        Lead lead_rec1 = new Lead();
        lead_rec1.LeadSource = 'Healthy Buildings - SPIFF';
        lead_rec1.Sender_Name__c = 'Test Name';
        lead_rec1.Email = 'abc@gmail.com';
        lead_rec1.Sender_Email__c = 'abc@gmail.com';
        lead_rec1.Phone = '1324646164';
        lead_rec1.Sender_Phone__c = '1234654897';
        lead_rec1.Sending_Business__c = 'FSP Global Access - ONITY';
        lead_rec1.Receiving_Business__c = 'Commercial HVAC Equipment';
        lead_rec1.Customer_Discussion_Date__c = date.today();
        lead_rec1.Customer_Details__c = 'test';
        lead_rec1.Customer_Budget__c = '1000';
        lead_rec1.Customer_Interest__c = 'Test';
        lead_rec1.Contact_Details__c = 'Yes';
        lead_rec1.Solutions_Interested__c = 'ActivAir(TM)';
        lead_rec1.FirstName = 'Test Contact';
        lead_rec1.LastName = 'Last Contact';
        lead_rec1.Company = 'UTC';
        lead_rec1.Street = 'Test street';
        lead_rec1.State = 'Test state';
        lead_rec1.City = 'Test city';
        lead_rec1.Country = 'Test country';
        lead_rec1.PostalCode = '12354';
        lead_rec1.Industry = 'Testing';
        lead_rec1.Title = 'Other Title';
        insert lead_rec1;
        
        Lead lead_rec2 = new Lead();
        lead_rec2.LeadSource = 'Healthy Buildings - SPIFF';
        lead_rec2.Sender_Name__c = 'Test Name';
        lead_rec2.Email = 'abc@gmail.com';
        lead_rec2.Sender_Email__c = 'abc@gmail.com';
        lead_rec2.Phone = '1324646164';
        lead_rec2.Sender_Phone__c = '1234654897';
        lead_rec2.Sending_Business__c = 'FSP Global Access - LENEL S2';
        lead_rec2.Receiving_Business__c = 'FSP Global Access - ONITY';
        lead_rec2.Customer_Discussion_Date__c = date.today() + 10 ;
        lead_rec2.Customer_Details__c = 'test';
        lead_rec2.Customer_Budget__c = '1200';
        lead_rec2.Contact_Details__c = 'Yes';
        lead_rec2.Customer_Interest__c = 'Test';
        lead_rec2.Solutions_Interested__c = 'Advanced Access Services';
        lead_rec2.FirstName = 'Test Contact';
        lead_rec2.LastName = 'Last Contact';
        lead_rec2.Company = 'UTC';
        lead_rec2.Street = 'Test street';
        lead_rec2.State = 'Test state';
        lead_rec2.City = 'Test city';
        lead_rec2.Country = 'Test country';
        lead_rec2.PostalCode = '12354';
        lead_rec2.Industry = 'Clinics/ Medical Centers';
        lead_rec2.Title = 'Other Title';
        insert lead_rec2;
        
        Lead lead_rec3 = new Lead();
        lead_rec3.LeadSource = 'Healthy Buildings - SPIFF';
        lead_rec3.Sender_Name__c = 'Test Name';
        lead_rec3.Email = 'abc@gmail.com';
        lead_rec3.Sender_Email__c = 'abc@gmail.com';
        lead_rec3.Phone = '1324646164';
        lead_rec3.Sender_Phone__c = '1234654897';
        lead_rec3.Sending_Business__c = 'FSP Global Access - ONITY';
        lead_rec3.Receiving_Business__c = 'FSP Global Access - LENEL S2';
        lead_rec3.Customer_Discussion_Date__c = date.today() +20;
        lead_rec3.Customer_Details__c = 'test';
        lead_rec3.Customer_Budget__c = '1500';
        lead_rec3.Customer_Interest__c = 'Test';
        lead_rec3.Contact_Details__c = 'Yes';
        lead_rec3.Solutions_Interested__c = 'Advanced Access Services';
        lead_rec3.FirstName = 'Test Contact';
        lead_rec3.LastName = 'Last Contact';
        lead_rec3.Company = 'UTC';
        lead_rec3.Street = 'Test street';
        lead_rec3.State = 'Test state';
        lead_rec3.City = 'Test city';
        lead_rec3.Country = 'Test country';
        lead_rec3.PostalCode = '12354';
        lead_rec3.Industry = 'Testing';
        lead_rec3.Title = 'Other Title';
        insert lead_rec3;
        
        Lead lead_rec4 = new Lead();
        lead_rec4.LeadSource = 'Healthy Buildings - SPIFF';
        lead_rec4.Sender_Name__c = 'Test Name';
        lead_rec4.Email = 'abc@gmail.com';
        lead_rec4.Sender_Email__c = 'abc@gmail.com';
        lead_rec4.Phone = '1324646164';
        lead_rec4.Sender_Phone__c = '1234654897';
        lead_rec4.Sending_Business__c = 'FSP Global Access - ONITY';
        lead_rec4.Receiving_Business__c = 'NORESCO';
        lead_rec4.Customer_Discussion_Date__c = date.today() +30;
        lead_rec4.Customer_Details__c = 'test';
        lead_rec4.Contact_Details__c = 'Yes';
        lead_rec4.Customer_Budget__c = '2000';
        lead_rec4.Customer_Interest__c = 'Test';
        lead_rec4.Solutions_Interested__c = 'ActivAir(TM)';
        lead_rec4.FirstName = 'Test Contact';
        lead_rec4.LastName = 'Last Contact';
        lead_rec4.Company = 'UTC';
        lead_rec4.Street = 'Test street';
        lead_rec4.State = 'Test state';
        lead_rec4.City = 'Test city';
        lead_rec4.Country = 'Test country';
        lead_rec4.PostalCode = '12354';
        lead_rec4.Industry = 'Testing';
        lead_rec4.Title = 'Other Title';
        lead_rec4.Record_Reference_Id__c = lead_rec1.id;
        insert lead_rec4;
        
        List<Lead> Lead_Li = New List<Lead>();
        Lead_Li.add(lead_rec1);
        Lead_Li.add(lead_rec2);
        Lead_Li.add(lead_rec3);
        Lead_Li.add(lead_rec4);
        
        String jasonToReturn = ''+lead_rec4.Id;
        
        HBI_Leads_Mapping_By_Receiving_Business__mdt test_data = [SELECT Id, Named_Credential__c, Industry__c, Org_Record_Type__c FROM 
            													HBI_Leads_Mapping_By_Receiving_Business__mdt WHERE 
            													MasterLabel = :lead_rec2.Receiving_Business__c Order By Industry__c limit 1];
        
        	String extRecordTypeName = '';
            String namedCred = '';
            String extRecTypeId = '';
        extRecordTypeName = test_data.Org_Record_Type__c;
        namedCred = test_data.Named_Credential__c;
        
        StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
        System.debug('@mock '+mock);
        mock.setStaticResource('HBI_Batch_Response');
        mock.setStatusCode(200);
        mock.setHeader('Content-Type', 'application/json');
        Test.setMock(HttpCalloutMock.class, mock);
        
        test.startTest();
        
     //   LeadController.createLead(lead_rec1);
        LeadController.calloutToQueryExtData(namedCred, extRecordTypeName);
      	LeadController.sendandUpdateLead(lead_rec4.id);
        LeadController.sendandUpdateLead(lead_rec3.id);
        LeadController.sendandUpdateLead(lead_rec2.id);
        LeadController.processDataFromAllOrgs(Lead_Li);
      String strbody = LeadController.getExtLeadBody(extRecTypeId, lead_rec1);
        LeadController.calloutToSendLead(namedCred, strbody);
        LeadController.getCalloutResponse(integr.Endpoint__c, integr.Method__c, Integer.valueOf(integr.Timeout__c), jasonToReturn, integr.Content_Type__c);
        LeadController.getCalloutResponse(integr2.Endpoint__c, integr2.Method__c, Integer.valueOf(integr.Timeout__c),null, null);
        test.stopTest();
        
    }
    
    public static testMethod void testcase_3() 
    {
        Integration__c integr = new Integration__c();
        integr.Name = 'SendLead';
        integr.Endpoint__c = 'callout:NAMED_CREDENTIAL/services/data/v37.0/sobjects/Lead/';
        integr.Method__c = 'POST';
        integr.Timeout__c = '12000';
        integr.Content_Type__c = 'application/json';
        insert integr;
         
        Integration__c integr2 = new Integration__c();
        integr2.Name = 'DevSmart_QueryLead';
        integr2.Endpoint__c = 'callout:Salesforce_DevSmart/services/data/v37.0/query?q=';
        integr2.Method__c = 'GET';
        integr2.Timeout__c = '12000';
        integr2.Content_Type__c = 'application/json';
        insert integr2;
        
        Integration__c integr3 = new Integration__c();
        integr3.Name = 'QueryExternalData';
        integr3.Endpoint__c = 'callout:NAMED_CREDENTIAL/services/data/v37.0/query?q=';
        integr3.Method__c = 'GET';
        integr3.Timeout__c = '12000';
        integr3.Content_Type__c = 'application/json';
        insert integr3;
        
        Lead lead_rec1 = new Lead();
        lead_rec1.LeadSource = 'Healthy Buildings - SPIFF';
        lead_rec1.Sender_Name__c = 'Test Name';
        lead_rec1.Email = 'abc@gmail.com';
        lead_rec1.Sender_Email__c = 'abc@gmail.com';
        lead_rec1.Phone = '1324646164';
        lead_rec1.Sender_Phone__c = '1234654897';
        lead_rec1.Sending_Business__c = 'FSP Global Access - ONITY';
        lead_rec1.Receiving_Business__c = 'Commercial HVAC Equipment';
        lead_rec1.Customer_Discussion_Date__c = date.today();
        lead_rec1.Customer_Details__c = 'test';
        lead_rec1.Customer_Budget__c = '1000';
        lead_rec1.Customer_Interest__c = 'Test';
        lead_rec1.Solutions_Interested__c = 'ActivAir(TM)';
        lead_rec1.FirstName = 'Test Contact';
        lead_rec1.LastName = 'Last Contact';
        lead_rec1.Company = 'UTC';
        lead_rec1.Street = 'Test street';
        lead_rec1.State = 'Test state';
        lead_rec1.City = 'Test city';
        lead_rec1.Country = 'Test country';
        lead_rec1.PostalCode = '12354';
        lead_rec1.Industry = 'Testing';
        lead_rec1.Title = 'Other Title';
        insert lead_rec1;
        
        Lead lead_rec2 = new Lead();
        lead_rec2.LeadSource = 'Healthy Buildings - SPIFF';
        lead_rec2.Sender_Name__c = 'Test Name';
        lead_rec2.Email = 'abc@gmail.com';
        lead_rec2.Sender_Email__c = 'abc@gmail.com';
        lead_rec2.Phone = '1324646164';
        lead_rec2.Sender_Phone__c = '1234654897';
        lead_rec2.Sending_Business__c = 'FSP Global Access - LENEL S2';
        lead_rec2.Receiving_Business__c = 'FSP Global Access - ONITY';
        lead_rec2.Customer_Discussion_Date__c = date.today() + 10 ;
        lead_rec2.Customer_Details__c = 'test';
        lead_rec2.Customer_Budget__c = '1200';
        lead_rec2.Customer_Interest__c = 'Test';
        lead_rec2.Solutions_Interested__c = 'Advanced Access Services';
        lead_rec2.FirstName = 'Test Contact';
        lead_rec2.LastName = 'Last Contact';
        lead_rec2.Company = 'UTC';
        lead_rec2.Street = 'Test street';
        lead_rec2.State = 'Test state';
        lead_rec2.City = 'Test city';
        lead_rec2.Country = 'Test country';
        lead_rec2.PostalCode = '12354';
        lead_rec2.Industry = 'Testing';
        lead_rec2.Title = 'Other Title';
        insert lead_rec2;
        
        Lead lead_rec3 = new Lead();
        lead_rec3.LeadSource = 'Healthy Buildings - SPIFF';
        lead_rec3.Sender_Name__c = 'Test Name';
        lead_rec3.Email = 'abc@gmail.com';
        lead_rec3.Sender_Email__c = 'abc@gmail.com';
        lead_rec3.Phone = '1324646164';
        lead_rec3.Sender_Phone__c = '1234654897';
        lead_rec3.Sending_Business__c = 'FSP Global Access - ONITY';
        lead_rec3.Receiving_Business__c = 'FSP Global Access - LENEL S2';
        lead_rec3.Customer_Discussion_Date__c = date.today() +20;
        lead_rec3.Customer_Details__c = 'test';
        lead_rec3.Customer_Budget__c = '1500';
        lead_rec3.Customer_Interest__c = 'Test';
        lead_rec3.Solutions_Interested__c = 'Advanced Access Services';
        lead_rec3.FirstName = 'Test Contact';
        lead_rec3.LastName = 'Last Contact';
        lead_rec3.Company = 'UTC';
        lead_rec3.Street = 'Test street';
        lead_rec3.State = 'Test state';
        lead_rec3.City = 'Test city';
        lead_rec3.Country = 'Test country';
        lead_rec3.PostalCode = '12354';
        lead_rec3.Industry = 'Testing';
        lead_rec3.Title = 'Other Title';
        insert lead_rec3;
        
        Lead lead_rec4 = new Lead();
        lead_rec4.LeadSource = 'Healthy Buildings - SPIFF';
        lead_rec4.Sender_Name__c = 'Test Name';
        lead_rec4.Email = 'abc@gmail.com';
        lead_rec4.Sender_Email__c = 'abc@gmail.com';
        lead_rec4.Phone = '1324646164';
        lead_rec4.Sender_Phone__c = '1234654897';
        lead_rec4.Sending_Business__c = 'FSP Global Access - ONITY';
        lead_rec4.Receiving_Business__c = 'NORESCO';
        lead_rec4.Customer_Discussion_Date__c = date.today() +30;
        lead_rec4.Customer_Details__c = 'test';
        lead_rec4.Customer_Budget__c = '2000';
        lead_rec4.Customer_Interest__c = 'Test';
        lead_rec4.Solutions_Interested__c = 'ActivAir(TM)';
        lead_rec4.FirstName = 'Test Contact';
        lead_rec4.LastName = 'Last Contact';
        lead_rec4.Company = 'UTC';
        lead_rec4.Street = 'Test street';
        lead_rec4.State = 'Test state';
        lead_rec4.City = 'Test city';
        lead_rec4.Country = 'Test country';
        lead_rec4.PostalCode = '12354';
        lead_rec4.Industry = 'Testing';
        lead_rec4.Title = 'Other Title';
        insert lead_rec4;
        
         Lead lead_rec5 = new Lead();
        lead_rec5.LeadSource = 'Healthy Buildings - SPIFF';
        lead_rec5.Sender_Name__c = 'Test Name';
        lead_rec5.Email = 'abc@gmail.com';
        lead_rec5.Sender_Email__c = 'abc@gmail.com';
        lead_rec4.Phone = '1324646164';
        lead_rec5.Sender_Phone__c = '1234654897';
        lead_rec5.Sending_Business__c = 'FSP Global Access - ONITY';
        lead_rec5.Receiving_Business__c = 'Commercial HVAC Equipment';
        lead_rec5.Customer_Discussion_Date__c = date.today() +30;
        lead_rec5.Customer_Details__c = 'test';
        lead_rec5.Customer_Budget__c = '2000';
        lead_rec5.Customer_Interest__c = 'Test';
        lead_rec5.Solutions_Interested__c = 'ActivAir(TM)';
        lead_rec5.FirstName = 'Test Contact';
        lead_rec5.LastName = 'Last Contact';
        lead_rec5.Company = 'UTC';
        lead_rec5.Street = 'Test street';
        lead_rec5.State = 'Test state';
        lead_rec5.City = 'Test city';
        lead_rec5.Country = 'Test country';
        lead_rec5.PostalCode = '12354';
        lead_rec5.Industry = 'Testing';
        lead_rec5.Title = 'Other Title';
        insert lead_rec5;
        
        List<Lead> Lead_Li = New List<Lead>();
        Lead_Li.add(lead_rec1);
        Lead_Li.add(lead_rec2);
        Lead_Li.add(lead_rec3);
        Lead_Li.add(lead_rec4);
        Lead_Li.add(lead_rec5);
        
        test.startTest();
        LeadController.processDataFromAllOrgs(Lead_Li);
        test.stopTest();
        
    }
    
    public static testMethod void testcase_2() 
    {
        Integration__c integr = new Integration__c();
        integr.Name = 'SendLead';
        integr.Endpoint__c = 'callout:NAMED_CREDENTIAL/services/data/v37.0/sobjects/Lead/';
        integr.Method__c = 'POST';
        integr.Timeout__c = '12000';
        integr.Content_Type__c = 'application/json';
        insert integr;
        
        
        
        List <Lead> Lead_Li = New List<Lead>();
        
        Lead lead_rec1 = new Lead();
        lead_rec1.LeadSource = 'Healthy Buildings - SPIFF';
        lead_rec1.Sender_Name__c = 'Test Name';
        lead_rec1.Email = 'abc@gmail.com';
        lead_rec1.Sender_Email__c = 'abc@gmail.com';
        lead_rec1.Phone = '1324646164';
        lead_rec1.Sender_Phone__c = '1234654897';
        lead_rec1.Sending_Business__c = 'FSP Global Access - ONITY';
        lead_rec1.Receiving_Business__c = 'Commercial HVAC Equipment';
        lead_rec1.Customer_Discussion_Date__c = date.today();
        lead_rec1.Customer_Details__c = 'test';
        lead_rec1.Customer_Budget__c = '1000';
        lead_rec1.Customer_Interest__c = 'Test';
        lead_rec1.Solutions_Interested__c = 'ActivAir(TM)';
        lead_rec1.FirstName = 'Test Contact';
        lead_rec1.LastName = 'Last Contact';
        lead_rec1.Company = 'UTC';
        lead_rec1.Street = 'Test street';
        lead_rec1.State = 'Test state';
        lead_rec1.City = 'Test city';
        lead_rec1.Country = 'Test country';
        lead_rec1.PostalCode = '12354';
        lead_rec1.Industry = 'Testing';
        lead_rec1.Title = 'Other Title';
        insert lead_rec1;
        
        Lead lead_rec2 = new Lead();
        lead_rec2.LeadSource = 'Healthy Buildings - SPIFF';
        lead_rec2.Sender_Name__c = 'Test Name';
        lead_rec2.Email = 'abc@gmail.com';
        lead_rec2.Sender_Email__c = 'abc@gmail.com';
        lead_rec2.Phone = '1324646164';
        lead_rec2.Sender_Phone__c = '1234654897';
        lead_rec2.Sending_Business__c = 'FSP Global Access - LENEL S2';
        lead_rec2.Receiving_Business__c = 'FSP Global Access - ONITY';
        lead_rec2.Customer_Discussion_Date__c = date.today() + 10 ;
        lead_rec2.Customer_Details__c = 'test';
        lead_rec2.Customer_Budget__c = '1200';
        lead_rec2.Customer_Interest__c = 'Test';
        lead_rec2.Solutions_Interested__c = 'Advanced Access Services';
        lead_rec2.FirstName = 'Test Contact';
        lead_rec2.LastName = 'Last Contact';
        lead_rec2.Company = 'UTC';
        lead_rec2.Street = 'Test street';
        lead_rec2.State = 'Test state';
        lead_rec2.City = 'Test city';
        lead_rec2.Country = 'Test country';
        lead_rec2.PostalCode = '12354';
        lead_rec2.Industry = 'Testing';
        lead_rec2.Title = 'Other Title';
        insert lead_rec2;
        
        Lead lead_rec3 = new Lead();
        lead_rec3.LeadSource = 'Healthy Buildings - SPIFF';
        lead_rec3.Sender_Name__c = 'Test Name';
        lead_rec3.Email = 'abc@gmail.com';
        lead_rec3.Sender_Email__c = 'abc@gmail.com';
        lead_rec3.Phone = '1324646164';
        lead_rec3.Sender_Phone__c = '1234654897';
        lead_rec3.Sending_Business__c = 'FSP Global Access - ONITY';
        lead_rec3.Receiving_Business__c = 'FSP Global Access - LENEL S2';
        lead_rec3.Customer_Discussion_Date__c = date.today() +20;
        lead_rec3.Customer_Details__c = 'test';
        lead_rec3.Customer_Budget__c = '1500';
        lead_rec3.Customer_Interest__c = 'Test';
        lead_rec3.Solutions_Interested__c = 'Advanced Access Services';
        lead_rec3.FirstName = 'Test Contact';
        lead_rec3.LastName = 'Last Contact';
        lead_rec3.Company = 'UTC';
        lead_rec3.Street = 'Test street';
        lead_rec3.State = 'Test state';
        lead_rec3.City = 'Test city';
        lead_rec3.Country = 'Test country';
        lead_rec3.PostalCode = '12354';
        lead_rec3.Industry = 'Testing';
        lead_rec3.Title = 'Other Title';
        insert lead_rec3;
        
        Lead lead_rec4 = new Lead();
        lead_rec4.LeadSource = 'Healthy Buildings - SPIFF';
        lead_rec4.Sender_Name__c = 'Test Name';
        lead_rec4.Email = 'abc@gmail.com';
        lead_rec4.Sender_Email__c = 'abc@gmail.com';
        lead_rec4.Phone = '1324646164';
        lead_rec4.Sender_Phone__c = '1234654897';
        lead_rec4.Sending_Business__c = 'FSP Global Access - ONITY';
        lead_rec4.Receiving_Business__c = 'NORESCO';
        lead_rec4.Customer_Discussion_Date__c = date.today() +30;
        lead_rec4.Customer_Details__c = 'test';
        lead_rec4.Contact_Details__c = 'Yes';
        lead_rec4.Customer_Budget__c = '2000';
        lead_rec4.Customer_Interest__c = 'Test';
        lead_rec4.Solutions_Interested__c = 'ActivAir(TM)';
        lead_rec4.FirstName = 'Test Contact';
        lead_rec4.LastName = 'Last Contact';
        lead_rec4.Company = 'UTC';
        lead_rec4.Street = 'Test street';
        lead_rec4.State = 'Test state';
        lead_rec4.City = 'Test city';
        lead_rec4.Country = 'Test country';
        lead_rec4.PostalCode = '12354';
        lead_rec4.Industry = 'Testing';
        lead_rec4.Title = 'Other Title';
        insert lead_rec4;
        
        Lead_Li.add(lead_rec1);
        Lead_Li.add(lead_rec2);
        Lead_Li.add(lead_rec3);
        Lead_Li.add(lead_rec4);
        
        String jasonToReturn = ''+lead_rec1.Id;
        
        test.startTest();
        LeadController.processDataFromAllOrgs(Lead_Li);
        LeadController.getCalloutResponse(integr.Endpoint__c, integr.Method__c, Integer.valueOf(integr.Timeout__c), jasonToReturn, integr.Content_Type__c);
        test.stopTest();
        
    }
    
    public static testMethod void testcase_4() 
    {
        Integration__c integr = new Integration__c();
        integr.Name = 'SendLead';
        integr.Endpoint__c = 'callout:NAMED_CREDENTIAL/services/data/v37.0/sobjects/Lead/';
        integr.Method__c = 'POST';
        integr.Timeout__c = '12000';
        integr.Content_Type__c = 'application/json';
        insert integr;
        
        Integration__c integr3 = new Integration__c();
        integr3.Name = 'QueryExternalData';
        integr3.Endpoint__c = 'callout:NAMED_CREDENTIAL/services/data/v37.0/query?q=';
        integr3.Method__c = 'GET';
        integr3.Timeout__c = '12000';
        integr3.Content_Type__c = 'application/json';
        insert integr3;
        
        Lead lead_rec = New Lead();
        lead_rec.LastName = 'Last Contact';
        lead_rec.Company = 'UTC';
        lead_rec.Sending_Business__c = 'NORESCO';
        lead_rec.Receiving_Business__c = 'BSG';
        
        StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
        mock.setStaticResource('HBI_Batch_Response');
        mock.setStatusCode(200);
        mock.setHeader('Content-Type', 'application/json');
        Test.setMock(HttpCalloutMock.class, mock);
        LeadController.createLead(lead_rec);
        Test.startTest();
        Database.executeBatch(new HBILeadsBatch());
        Test.stopTest();
    }
}