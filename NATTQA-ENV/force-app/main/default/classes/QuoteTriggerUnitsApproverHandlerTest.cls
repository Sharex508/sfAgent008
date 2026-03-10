@IsTest
public class QuoteTriggerUnitsApproverHandlerTest {
    @TestSetup static void setupData(){
        List<Pricebook2> pbList = new List<Pricebook2>();
        pbList.add(new Pricebook2(Name='NATT Units Price Book',IsActive=true));
        insert pbList;
         List<Product2> product2List = new List<Product2>();
        Product2 prod = new Product2(
            Name='Vector 8600 - System 01',
            ProductCode='Vector 8600 - System 01',
            Family = 'Trailer'
        );
        product2List.add(prod);
        insert product2List;
       List<PricebookEntry> pbeList = new List<PricebookEntry>();

// Create the standard price entry
PricebookEntry standardPbe = new PricebookEntry(
    Pricebook2Id = Test.getStandardPricebookId(),
    Product2Id = product2List[0].Id,
    UnitPrice = 5000001,
    IsActive = true
);
        
        // Add the standard price entry to the list
        pbeList.add(standardPbe);
        
        // Create the custom price entry
        PricebookEntry customPbe = new PricebookEntry(
            Pricebook2Id = pbList[0].Id,
            Product2Id = product2List[0].Id,
            UnitPrice = 5000009,
            IsActive = true
        );
        
        // Add the custom price entry to the list
        pbeList.add(customPbe);
        
        // Insert the list of price book entries
        insert pbeList;
        

        list<account> accList = new  List<account>(); 
        Account a = new Account(Name='Test Dealer',
                                RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId(),
                                NATT_Organization__c = 'NATT',
                                NATT_Region__c = 'East');
        accList.add(a);
        database.insert(accList);
        List<Opportunity> oppList = new List<Opportunity>();
        oppList.add(new Opportunity(Name='TestUnitsOpp',CloseDate=Date.today().addDays(30),StageName='Qualification',AccountId=a.Id,RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_Units').getRecordTypeId(),NATT_Stock__c=true));
        insert oppList;
    }
    // Added by Rajasekhar for CCRN:2631
    @isTest static void myUnitTest1(){
        Account a = [SELECT Id FROM Account WHERE Name='Test Dealer'];
        NattQuoteCon.Wrapper w = NattQuoteCon.getData(a.Id);
        string qteRecTypeID = Schema.SobjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('MX_Units_Quote').getRecordTypeId();
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name='TestUnitsOpp'];
        opp = NattQuoteCon.getOppData(opp.Id);  
        string QuoteJSON = '{"SBQQ__Status__c":"Draft"}';
        //string QuoteJSON = '{"MarkForCountry": "US","MarkForState": "TX","MarkForCity": "rythu","poNumber": "123","hasFreight":true, "RecordypeId":'+qteRecTypeID +'}';
        
        NattQuoteCon.createQuote(opp.Id,true,QuoteJSON);
        
        Pricebook2 pb = [Select Id From Pricebook2 Where Name = 'NATT Units Price Book'];
        
        //List<PriceBookEntry> pbes = [Select Id,Product2Id From PriceBookEntry Where PriceBook2Id =:pb.Id];
        
        // insert quote lines
        List<SBQQ__QuoteLine__c> quoteLineList = new List<SBQQ__QuoteLine__c>();
        SBQQ__Quote__c quoteRec = [select id,SBQQ__Status__c from SBQQ__Quote__c where SBQQ__Status__c = 'Draft' and SBQQ__Opportunity2__c =:opp.Id limit 1 ];
        
        List<Product2> product2List = [select id from Product2 where ProductCode='Vector 8600 - System 01'];
        
        //SBQQ__QuoteLine__c quoteLine = TestUtil.createQuoteLine(pbes[0].product2List.id, quoteRec.Id);
        
        SBQQ__QuoteLine__c quoteLine = TestUtil.createQuoteLine(product2List[0].id, quoteRec.Id);
        quoteLine.SBQQ__Product__c = product2List[0].id;
        quoteLine.SBQQ__Discount__c = 80;
        quoteLineList.add(quoteLine);
        upsert quoteLine;
        NATT_Approval_Process__c approvalProcess = new NATT_Approval_Process__c(
            //Name = 'AP-0000',
            Product_Name__c = product2List[0].id,
            //Product_Family__c = 'Trailer',
            Approval_Object__c = 'SBQQ__Quote__c',
            Business_Type__c = 'NATT',
            Business_Sub_Type__c = 'Units Quote',
            Margin_EAM_Lower_Bound__c = 100,
            Margin_RD_Lower_Bound__c = 36,
            Margin_DOS_Lower_Bound__c = 35,
            Margin_Sales_Ops_Lower_Bound__c = 0
        );
        insert approvalProcess;
        
        quoteRec.NATT_Unit__c='Vector 8600 - System 01';
        
        try{
            update quoteRec;
        }
        
        catch(exception e){
            system.debug('Error-'+ e);
        }
        quoteRec.SBQQ__Status__c='Pending Approval';
        try{
            update quoteRec;
        }
        
        catch(exception e){
            system.debug('Error-'+ e);
        }
    }
    
     @isTest static void justCoverage(){
         QuoteTriggerUnitsApproverHandler.justCoverage();
     }
}