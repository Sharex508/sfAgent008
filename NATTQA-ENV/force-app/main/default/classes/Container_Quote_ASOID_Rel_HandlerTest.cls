/********************************************************************************************************
* @author         (Deloitte)
* @description    This is a test class for CONTAINERQuoteSnapshotReview class code coverage.
* @date           09/02/2022 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Deloitte               09/02/2022                                  Initial version
*********************************************************************************************************/

@isTest
public with sharing class Container_Quote_ASOID_Rel_HandlerTest{
    @testSetup 
    static void setup() {
        
        // This code runs as the system user
        Profile prof = [SELECT Id FROM Profile WHERE Name='CONTAINER Administrator'];
        User newUser = new User(Alias = 'contAdm', Email='contAdmin@carrier.com', LastName='AdminTest', ProfileId = prof.Id, 
                                UserName='testAdminUser@carrier.com', EmailEncodingKey='UTF-8', 
                                LanguageLocaleKey='en_US', LocaleSidKey='en_US', TimeZoneSidKey='America/Los_Angeles');
        insert newUser;
        
        System.runAs(newUser) {
            //CONTAINER_UtilityClass.createCustomerQuote();
        }
    }
    @isTest
    static void validatecontainer_ASOID_UpdateNT() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
        CONTAINER_UtilityClass.createCustomerQuoteBulk_Genset();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            //quoteList[0].CONTAINER_ASO_ID__c='';
            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            //update quoteList[0];
            if(quoteList!=null && quoteList.size()>0){
                quoteIdList.add(quoteList[0].id);
                quoteIdList.add(quoteList[1].id);
    
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
    }
    @isTest
    static void validatecontainer_ASOID_UpdateNT2() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuoteBulk_Genset();
        CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c='';
            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList[0];
            if(quoteList!=null && quoteList.size()>0){
                quoteIdList.add(quoteList[0].id);
                //quoteIdList.add(quoteList[1].id);
    
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
    }
    @isTest
    static void validatecontainer_ASOID_UpdateNT3() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
        CONTAINER_UtilityClass.createCustomerQuoteBulk_Genset();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c='';
            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList[0];
            if(quoteList!=null && quoteList.size()>0){
                for(Integer i=0;i<quoteList.size();i++){
                quoteIdList.add(quoteList[i].id);
                //quoteIdList.add(quoteList[1].id);
                }
            }
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
    @isTest
    static void validatecontainer_ASOID_UpdateNT4() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
        CONTAINER_UtilityClass.createCustomerQuoteBulk_Genset();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c='';
            quoteList[1].CONTAINER_ASO_ID__c='990';

            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList;
            if(quoteList!=null && quoteList.size()>0){
                for(Integer i=0;i<quoteList.size();i++){
                quoteIdList.add(quoteList[i].id);
                //quoteIdList.add(quoteList[1].id);
                }
            }
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
    @isTest
    static void validatecontainer_ASOID_UpdateNT5() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
        CONTAINER_UtilityClass.createCustomerQuoteBulk_Genset();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c='';
            quoteList[0].CONTAINER_NT_Previous_ASO_ID__c='12';
            //quoteList[1].CONTAINER_ASO_ID__c='7';
            //quoteList[2].CONTAINER_ASO_ID__c='2';


            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList;
            if(quoteList!=null && quoteList.size()>0){
                for(Integer i=0;i<quoteList.size();i++){
                quoteIdList.add(quoteList[i].id);
                //quoteIdList.add(quoteList[1].id);
                }
            }
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
    @isTest
    static void validatecontainer_ASOID_UpdateGenset() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
        CONTAINER_UtilityClass.createCustomerQuoteBulk_NT();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            //quoteList[0].CONTAINER_ASO_ID__c='';
            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            //update quoteList[0];
            if(quoteList!=null && quoteList.size()>0){
                quoteIdList.add(quoteList[0].id);
                quoteIdList.add(quoteList[1].id);
    
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
    }
    @isTest
    static void validatecontainer_ASOID_UpdateGenset2() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuoteBulk_Genset();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
			CONTAINER_UtilityClass.createCustomerQuote();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c='';
            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList[0];
            if(quoteList!=null && quoteList.size()>0){
                quoteIdList.add(quoteList[0].id);
                //quoteIdList.add(quoteList[1].id);
    
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
    }
    @isTest
    static void validatecontainer_ASOID_UpdateGenset3() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
        CONTAINER_UtilityClass.createCustomerQuoteBulk_NT();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c='';
            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList[0];
            if(quoteList!=null && quoteList.size()>0){
                for(Integer i=0;i<quoteList.size();i++){
                quoteIdList.add(quoteList[i].id);
                //quoteIdList.add(quoteList[1].id);
                }
            }
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
    @isTest
    static void validatecontainer_ASOID_UpdateGenset4() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
        CONTAINER_UtilityClass.createCustomerQuoteBulk_NT();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c='';
            quoteList[1].CONTAINER_ASO_ID__c='990';

            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList;
            if(quoteList!=null && quoteList.size()>0){
                for(Integer i=0;i<quoteList.size();i++){
                quoteIdList.add(quoteList[i].id);
                //quoteIdList.add(quoteList[1].id);
                }
            }
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
    @isTest
    static void validatecontainer_ASOID_UpdateGenset5() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
        CONTAINER_UtilityClass.createCustomerQuoteBulk_NT();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c='';
            quoteList[0].CONTAINER_NT_Previous_ASO_ID__c='12';
            //quoteList[1].CONTAINER_ASO_ID__c='7';
            //quoteList[2].CONTAINER_ASO_ID__c='2';


            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList;
            if(quoteList!=null && quoteList.size()>0){
                for(Integer i=0;i<quoteList.size();i++){
                quoteIdList.add(quoteList[i].id);
                //quoteIdList.add(quoteList[1].id);
                }
            }
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
    @isTest
    static void validatecontainer_ASOID_UpdateGenset6() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuoteBulk_Genset();
        CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c='';
            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList[0];
            if(quoteList!=null && quoteList.size()>0){
                quoteIdList.add(quoteList[0].id);
                //quoteIdList.add(quoteList[1].id);
    
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
    }
    @isTest
    static void validatecontainer_ASOID_UpdateGenset7() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
        CONTAINER_UtilityClass.createCustomerQuoteBulk_NT();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c=NULL;
            quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='12';
            update quoteList[0];
            if(quoteList!=null && quoteList.size()>0){
                quoteIdList.add(quoteList[0].id);
                quoteIdList.add(quoteList[1].id);
    
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
    }
    @isTest
    static void validatecontainer_ASOID_UpdateGenset8() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
        CONTAINER_UtilityClass.createCustomerQuoteBulk_NT();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c=NULL;
            quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='12';
            update quoteList[0];
            if(quoteList!=null && quoteList.size()>0){
                quoteIdList.add(quoteList[0].id);
                quoteIdList.add(quoteList[1].id);
    
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
    }
     @isTest
    static void validatecontainer_ASOID_UpdateGenset9() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
        CONTAINER_UtilityClass.createCustomerQuoteBulk_NT();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c='1';
            quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='12';
            quoteList[0].CONTAINER_ASO_Rev__c ='1';
            update quoteList[0];
            if(quoteList!=null && quoteList.size()>0){
                quoteIdList.add(quoteList[0].id);
                quoteIdList.add(quoteList[1].id);
    
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
    }
    @isTest
    static void validatecontainer_ASOID_UpdateNT6() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuoteBulk_Genset();
        CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c='';
            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList[0];
            if(quoteList!=null && quoteList.size()>0){
                quoteIdList.add(quoteList[0].id);
                //quoteIdList.add(quoteList[1].id);
    
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
    }
    @isTest
    static void validatecontainer_ASOID_UpdateNT7() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
			CONTAINER_UtilityClass.createCustomerQuoteBulk_Genset();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c=NULL;
            quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='12';
            update quoteList[0];
            if(quoteList!=null && quoteList.size()>0){
                quoteIdList.add(quoteList[0].id);
                quoteIdList.add(quoteList[1].id);
    
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
    }
    @isTest
    static void validatecontainer_ASOID_UpdateNT8() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
        	CONTAINER_UtilityClass.createCustomerQuoteBulk_Genset();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c=NULL;
            quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='12';
            update quoteList[0];
            if(quoteList!=null && quoteList.size()>0){
                quoteIdList.add(quoteList[0].id);
                quoteIdList.add(quoteList[1].id);
    
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
    }
     @isTest
    static void validatecontainer_ASOID_UpdateNT9() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
            CONTAINER_UtilityClass.createCustomerQuoteBulk_Genset();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c='1';
            quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='12';
            quoteList[0].CONTAINER_ASO_Rev__c ='1';
            update quoteList[0];
            if(quoteList!=null && quoteList.size()>0){
                quoteIdList.add(quoteList[0].id);
                quoteIdList.add(quoteList[1].id);
    
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
    }
     @isTest
    static void validatecontainer_ASOID_UpdateNT10() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
        CONTAINER_UtilityClass.createCustomerQuoteBulk_Genset();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c='';
            quoteList[0].CONTAINER_NT_Previous_ASO_ID__c='12';
            quoteList[1].CONTAINER_ASO_ID__c='7';
            quoteList[2].CONTAINER_ASO_ID__c='2';


            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList;
            if(quoteList!=null && quoteList.size()>0){
                for(Integer i=0;i<quoteList.size();i++){
                quoteIdList.add(quoteList[i].id);
                //quoteIdList.add(quoteList[1].id);
                }
            }
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
     @isTest
    static void validatecontainer_ASOID_UpdateNT11() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
        CONTAINER_UtilityClass.createCustomerQuoteBulk_Genset();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c='';
            quoteList[0].CONTAINER_NT_Previous_ASO_ID__c='5';
            quoteList[1].CONTAINER_ASO_ID__c='7';
            quoteList[2].CONTAINER_ASO_ID__c='2';


            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList;
            if(quoteList!=null && quoteList.size()>0){
                for(Integer i=0;i<quoteList.size();i++){
                quoteIdList.add(quoteList[i].id);
                //quoteIdList.add(quoteList[1].id);
                }
            }
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
     @isTest
    static void validatecontainer_ASOID_UpdateNT12() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
        CONTAINER_UtilityClass.createCustomerQuoteBulk_Genset();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c='';
            quoteList[0].CONTAINER_NT_Previous_ASO_ID__c='5';
            quoteList[1].CONTAINER_ASO_ID__c='7';
            quoteList[2].CONTAINER_ASO_ID__c='223';


            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList;
            if(quoteList!=null && quoteList.size()>0){
                for(Integer i=0;i<quoteList.size();i++){
                quoteIdList.add(quoteList[i].id);
                //quoteIdList.add(quoteList[1].id);
                }
            }
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
     @isTest
    static void validatecontainer_ASOID_UpdateNT13() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
        CONTAINER_UtilityClass.createCustomerQuoteBulk_Genset();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c='';
            quoteList[0].CONTAINER_NT_Previous_ASO_ID__c='5';
            quoteList[1].CONTAINER_ASO_ID__c='7';
            quoteList[2].CONTAINER_ASO_ID__c='2234';


            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList;
            if(quoteList!=null && quoteList.size()>0){
                for(Integer i=0;i<quoteList.size();i++){
                quoteIdList.add(quoteList[i].id);
                //quoteIdList.add(quoteList[1].id);
                }
            }
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
     @isTest
    static void validatecontainer_ASOID_UpdateNT14() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
        CONTAINER_UtilityClass.createCustomerQuoteBulk_Genset();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c='';
            quoteList[1].CONTAINER_ASO_ID__c='7';
            quoteList[2].CONTAINER_ASO_ID__c='2234';
            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList;
            if(quoteList!=null && quoteList.size()>0){
                for(Integer i=0;i<quoteList.size();i++){
                quoteIdList.add(quoteList[i].id);
                //quoteIdList.add(quoteList[1].id);
                }
            }
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
    @isTest
    static void validatecontainer_ASOID_UpdateNT15() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
        CONTAINER_UtilityClass.createCustomerQuoteBulk_Genset();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c='';
            quoteList[1].CONTAINER_ASO_ID__c='7';
            quoteList[2].CONTAINER_ASO_ID__c='223';
            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList;
            if(quoteList!=null && quoteList.size()>0){
                for(Integer i=0;i<quoteList.size();i++){
                quoteIdList.add(quoteList[i].id);
                //quoteIdList.add(quoteList[1].id);
                }
            }
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
    @isTest
    static void validatecontainer_ASOID_UpdateNT16() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
        CONTAINER_UtilityClass.createCustomerQuoteBulk_Genset();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c='';
            quoteList[1].CONTAINER_ASO_ID__c='7';
            quoteList[2].CONTAINER_ASO_ID__c='2';
            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList;
            if(quoteList!=null && quoteList.size()>0){
                for(Integer i=0;i<quoteList.size();i++){
                quoteIdList.add(quoteList[i].id);
                //quoteIdList.add(quoteList[1].id);
                }
            }
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
     @isTest
    static void validatecontainer_ASOID_UpdateGenset15() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
            CONTAINER_UtilityClass.createCustomerQuoteBulk_NT();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c='';
            quoteList[0].CONTAINER_NT_Previous_ASO_ID__c='12';
            quoteList[1].CONTAINER_ASO_ID__c='7';
            quoteList[2].CONTAINER_ASO_ID__c='223';


            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList;
            if(quoteList!=null && quoteList.size()>0){
                for(Integer i=0;i<quoteList.size();i++){
                quoteIdList.add(quoteList[i].id);
                //quoteIdList.add(quoteList[1].id);
                }
            }
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
     @isTest
    static void validatecontainer_ASOID_UpdateGenset16() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
			CONTAINER_UtilityClass.createCustomerQuoteBulk_NT();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c='';
            quoteList[0].CONTAINER_NT_Previous_ASO_ID__c='12';
            quoteList[1].CONTAINER_ASO_ID__c='7';
            quoteList[2].CONTAINER_ASO_ID__c='8';


            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList;
            if(quoteList!=null && quoteList.size()>0){
                for(Integer i=0;i<quoteList.size();i++){
                quoteIdList.add(quoteList[i].id);
                //quoteIdList.add(quoteList[1].id);
                }
            }
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
    @isTest
    static void validatecontainer_ASOID_UpdateGenset17() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
        CONTAINER_UtilityClass.createCustomerQuoteBulk_NT();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            quoteList[0].CONTAINER_ASO_ID__c='';
            quoteList[0].CONTAINER_NT_Previous_ASO_ID__c='12';
            quoteList[1].CONTAINER_ASO_ID__c='7';
            quoteList[2].CONTAINER_ASO_ID__c='8234';


            //quoteList[0].CONTAINER_Genset_Previous_ASO_ID__c='';
            update quoteList;
            if(quoteList!=null && quoteList.size()>0){
                for(Integer i=0;i<quoteList.size();i++){
                quoteIdList.add(quoteList[i].id);
                //quoteIdList.add(quoteList[1].id);
                }
            }
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
     @isTest
    static void validatecontainer_ASOID_UpdateNT23() {
         User containerAdmin = [select id from user where Alias = 'contAdm' limit 1];

        //CONTAINER_UtilityClass.createCustomerQuote();
        List<String>quoteIdList = new List<String>();
        System.runAs(containerAdmin) {
        CONTAINER_UtilityClass.createCustomerQuoteBulk_Genset();

            CONTAINER_Quote_Revision_Mapping__mdt objMdt = new CONTAINER_Quote_Revision_Mapping__mdt();
            objMdt.Revision_Number__c= 123;
            objMdt.Revision_Name__c = 'Test';
            
            //Insert objMdt;
            List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c ];
            //quoteList[0].recordTypeId =Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
            //quoteList[0].CONTAINER_ASO_ID__c='';
            quoteList[0].CONTAINER_ASO_Rev__c='1';
             quoteList[0].CONTAINER_NT_RevNumber__c=1;
            update quoteList[0];
            if(quoteList!=null && quoteList.size()>0){
                quoteIdList.add(quoteList[0].id);
                quoteIdList.add(quoteList[1].id);
    
                Container_Quote_ASOID_Release_Handler.container_ASOID_Update(quoteIdList);
            }
        }
    }
    }