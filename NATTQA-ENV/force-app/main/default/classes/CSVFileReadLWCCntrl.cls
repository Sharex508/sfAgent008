public class CSVFileReadLWCCntrl {
    @AuraEnabled
    public static void csvFileRead(Id contentDocumentId){
        list<NATT_Backlog_Item__c> backlogInsertList = new list<NATT_Backlog_Item__c>();
        list<NATT_Backlog_Item__c> backlogUpdateList = new list<NATT_Backlog_Item__c>();
        
        if(contentDocumentId != null) {
            System.debug('Inside the apex');
            // Fetch File Data based on the basic of document id 
            ContentVersion contentVersionObj = [SELECT Id, VersionData FROM ContentVersion WHERE ContentDocumentId =:contentDocumentId ];
            System.debug('VersionData--> '+contentVersionObj.VersionData);
            // split the file data
            System.debug('File Data Review:::'+contentVersionObj.VersionData.toString());
            //System.debug(EncodingUtil.base64Decode(contentVersionObj.VersionData.toString()));
            //list<String> csvRecordsList = contentVersionObj.VersionData.toString().split('\n');
            
            String csvRecords = contentVersionObj.VersionData.toString();
            CSVFileParser csvparser = new CSVFileParser();
            List<String> csvRecordsList = csvParser.safeSplit(csvRecords, '\n');
            System.debug('csvRecordsList.size::'+csvRecordsList.size());
            System.debug('csvRecordsList----> '+csvRecordsList);
            
            for(Integer i = 1; i < csvRecordsList.size(); i++){
                list<String> csvRowData = csvRecordsList[i].split(',');
                
                if(csvRowData[0] != ''){
                    NATT_Backlog_Item__c backlogObj = new NATT_Backlog_Item__c();               
                    System.debug('csvRowData----> '+csvRowData);
                    backlogObj.NATT_Prod_No__c = csvRowData[0];
                    backlogObj.NATT_Prod_Description__c = csvRowData[1];
                    System.debug(backlogObj.NATT_Prod_Description__c);
                    backlogObj.NATT_Bill_To_Address__c = csvRowData[2];
                    System.debug('tttt::'+backlogObj.NATT_Bill_To_Address__c);
                    backlogObj.NATT_JDE_AR_Code__c = csvRowData[2];
                    backlogObj.NATT_Bill_To_Name__c = csvRowData[3];
                    backlogObj.NATT_End_User__c = csvRowData[4];
                    backlogObj.NATT_Customer_PO__c = csvRowData[5];
                    backlogObj.NATT_Region__c = csvRowData[6];
                    backlogObj.NATT_SOLine__c = csvRowData[7];
                    backlogObj.NATT_Order_Type__c = csvRowData[8];
                    backlogObj.NATT_Sch_Pick_Date__c = Date.parse(csvRowData[9]);
                    backlogObj.NATT_BklgQty__c = Decimal.valueOf(csvRowData[10]);
                    backlogObj.NATT_Req_Ship_Date__c = Date.parse(csvRowData[11]);
                    //backlogObj.NATT_Freight_Code__c = csvRowData[13];
                    backlogObj.NATT_Ship_To_City__c = csvRowData[14];
                    backlogObj.NATT_Ship_To_State__c = csvRowData[15];
                    //backlogObj.NATT_SO_Cat__c = csvRowData[16];
                    backlogObj.NATT_Product_Family__c = csvRowData[17];
                    backlogObj.NATT_Product_Line__c = csvRowData[18];
                    
                    backlogInsertList.add(backlogObj);
                    
                }

                    
             }
                            
        }
        
            try{    
                System.debug('Before insert');
                if(!backlogInsertList.isEmpty()) {
                    insert backlogInsertList;
                    System.debug('InsertSizeList-->' + backlogInsertList.size());
                    System.debug('After Insert insert');
                    System.debug('Before Backlog Item Update'); 
                }
                String prevBillToAdress ='';
                Map<String, User> newMap = new Map<String, User>{};
                    List<User> UserList = new List<User>();
                UserList = [Select Id, Name, Alias, ProfileId,AccountId, isActive,Account.NATT_JDE_Unit_Bill_To_Code__c from User where Profile.Name = 'NATT Sales Only Community' and Account.NATT_JDE_Unit_Bill_To_Code__c != null];
                for (User usr: UserList){
                    String billToAddress = usr.Account.NATT_JDE_Unit_Bill_To_Code__c;
                    if(prevBillToAdress != usr.Account.NATT_JDE_Unit_Bill_To_Code__c){
                        newMap.put(usr.Account.NATT_JDE_Unit_Bill_To_Code__c, usr);
                        prevBillToAdress = usr.Account.NATT_JDE_Unit_Bill_To_Code__c;
                    }
                    
                }
                System.debug('MAPSIZE--> ' + newMap.size());
                //System.debug('MAP--> ' + newMap);
                
                for(NATT_Backlog_Item__c backlogItem : backlogInsertList){
                    System.debug('BacklogItem Id--> '+backlogItem.Id);
                    User newusr = newMap.get(backlogItem.NATT_Bill_To_Address__c);
                    System.debug('User Details--> '+ newusr);
                    if(newusr != null){
                        if(newusr.isActive = true && newusr.AccountId != null){
                            System.debug('AccountId--> '+ newusr.AccountId);
                            backlogItem.NATT_Account__c = newusr.AccountId;
                            System.debug('OwnerId--> '+ newusr.Name);
                            backlogItem.OwnerId = newusr.Id;
                        }
                        if(newusr.IsActive && newusr.AccountId == null){
                            System.debug('OwnerId--> '+ newusr.Name);
                            backlogItem.OwnerId = newusr.Id;
                            System.debug('Account Id--> '+ newusr.AccountId);
                            continue;
                        }
                        if(!newusr.IsActive && newusr.AccountId != NULL){
                            System.debug('AccountId--> '+ newusr.AccountId);
                            backlogItem.NATT_Account__c = newusr.AccountId;
                            System.debug('OwnerId--> '+ UserInfo.getUserId());
                            continue;
                        }
                    }
                    backlogUpdateList.add(backlogItem);
                    
                }
                System.debug('UpdatedListSize-->' + backlogUpdateList.size());
                update backlogUpdateList;
                System.debug('After Backlog Item Update');
                
            }
            catch (Exception ex) {
                throw new AuraHandledException(ex.getMessage());
            } 
  
    }
}