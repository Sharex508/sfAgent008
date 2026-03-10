@isTest
public class CSVFileReadLWCCntrl_Test {
	public static String csvStr = 'Prod No,Prod Description,Bill To Address,Bill To Name,End User,Customer P.O.,Region,SOLine,Order Type,Sch Pick Date,BklgQty,req Ship Date,Hold Code,Freight Code,Ship To City,Ship To State,SO Cat.,Prod Family,Prod Line,Month,Year,Market \n NV85-STD,VECTOR 8500 W/STANDARD SPECS,48003417,ColdFront - Surrey BC,OCEAN TRAILER L,PO06952,EAST,10153236-7.0,S1,09/19/2022,3,07/12/2022,,PPA,SURREY,BC,TLO,Trailer,V8500,9,2022';
    
    @isTest
    public static void testReadCSVFile(){
        List<NATT_Backlog_Item__c> insertList = new List<NATT_Backlog_Item__c>();
        Test.startTest();
        ContentVersion contentVersionInsert = new ContentVersion(
            Title = 'Test',
            PathOnClient = 'Test.csv',
            VersionData = Blob.valueOf(csvStr),
            IsMajorVersion = true);
    
        insert contentVersionInsert;
        Id getId = [Select ContentDocumentId From ContentVersion Where Id =:contentVersionInsert.id].ContentDocumentId;
        String[] csvFileLines = csvStr.split('\n');
        
        for(Integer i = 1; i<csvFileLines.size(); i++){
            List<String> csvRecordData = csvFileLines[i].split(',');
            System.debug('CSVROWDATA-->' + csvRecordData);
            NATT_Backlog_Item__c bklg = new NATT_Backlog_Item__c();
            bklg.NATT_Prod_No__c = csvRecordData[0];
            bklg.NATT_Prod_Description__c= csvRecordData[1];
            bklg.NATT_Bill_To_Address__c = csvRecordData[2];
            bklg.NATT_Bill_To_Name__c = csvRecordData[3];
            bklg.NATT_End_User__c = csvRecordData[4];
            bklg.NATT_Customer_PO__c = csvRecordData[5];
            bklg.NATT_Region__c = csvRecordData[6];
            bklg.NATT_SOLine__c = csvRecordData[7];
            bklg.NATT_Order_Type__c = csvRecordData[8];
            bklg.NATT_Sch_Pick_Date__c = Date.parse(csvRecordData[9]);
            bklg.NATT_BklgQty__c = Decimal.valueOf(csvRecordData[10]);
            bklg.NATT_Req_Ship_Date__c = Date.parse(csvRecordData[11]);
            bklg.NATT_Ship_To_City__c = csvRecordData[14];
            bklg.NATT_Ship_To_State__c = csvRecordData[15];
            bklg.NATT_Product_Family__c = csvRecordData[17];
            bklg.NATT_Product_Line__c = csvRecordData[18];
            //System.debug('BKLG--> '+ bklg);
                
            insertList.add(bklg);
        }
        insert insertList;
        Account acc=new Account();
        acc.Name='testName';
        acc.NATT_JDE_Unit_Bill_To_Code__c='48002496';
        insert acc;
        
        Contact con = new Contact(LastName ='testCon',AccountId = acc.Id);
        insert con;  
        
        Profile p = [SELECT Id FROM Profile WHERE Name='NATT Sales Only Community']; 
        User u = new User(Alias = 'standt', Email='standarduser@testorg.com', 
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
                          LocaleSidKey='en_US', ProfileId = p.Id, ContactId=con.id, 
                          TimeZoneSidKey='America/Los_Angeles', UserName='NATTSalesOnlyCommunity@testorg.com');
        insert u;
        /*System.runAs(u) {
            // The following code runs as user 'u' 
            System.debug('Current User: ' + UserInfo.getUserName());
            System.debug('Current Profile: ' + UserInfo.getProfileId()); 
        }*/
        
        
        system.debug('insertList Size::'+insertList.size());
        system.debug('insertList ::'+insertList);
        CSVFileReadLWCCntrl.csvFileRead(getId);
        Test.stopTest();
    } 
}