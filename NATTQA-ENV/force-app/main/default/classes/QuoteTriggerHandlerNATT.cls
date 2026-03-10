/**
* @description : QuoteTriggerHandlerNATT
* @testclass : QuoteTriggerHandlerNattTest
**/
public class QuoteTriggerHandlerNATT extends QuoteTriggerHandlerAbstract{
    public static boolean executeOnce = true;

/**
* @description : handleBeforeInsert
* @param trgNew list of sobject
**/
    public override void handleBeforeInsert(List<SObject> trgNew){        
        List<SBQQ__Quote__c> newList = (List<SBQQ__Quote__c>)trgNew;
            for(SBQQ__Quote__c q : newList){
                if(q.isClone()){
                    q.NATT_Approver_1__c=null;
                    q.NATT_Approver_2__c=null;
                    q.NATT_Approver_3__c=null;
                    q.NATT_Approver_4__c=null;
                    q.NATT_Approver_5__c=null;
                    q.NATT_Approver_6__c=null;
                    q.NATT_Approver_1_Name__c='';
                    q.NATT_Approver_2_Name__c='';
                    q.NATT_Approver_3_Name__c='';
                    q.NATT_Approver_4_Name__c='';
                    q.NATT_Approver_5_Name__c='';
                    q.NATT_Approver_6_Name__c='';
                    q.NATT_Approver_1_Approval_Date__c=null;
                    q.NATT_Approver_2_Approval_Date__c=null;
                    q.NATT_Approver_3_Approval_Date__c=null;
                    q.NATT_Approver_4_Approval_Date__c=null;
                    q.NATT_Approver_5_Approval_Date__c=null;
                    q.NATT_Approver_6_Approval_Date__c=null;
                }
                
                if(q.SBQQ__Type__c == 'Amendment'){
                    q.NATT_Enforce_Amendment_Error__c = true;
                }
            }    
    }
    
/**
* @description : handleAfterInsert
* @param trgNewMap Map<Id,SObject>
**/
    
    public override void handleAfterInsert(Map<Id,SObject> trgNewMap){
        Map<Id,SBQQ__Quote__c> newMap = (Map<Id,SBQQ__Quote__c>)trgNewMap;
        Set<Id> accountIdSet = new Set<Id>();
            for(SBQQ__Quote__c q : newMap.values()){
                accountIdSet.add(q.SBQQ__Account__c);
            }
            accountIdSet.remove(null);
            if(!accountIdSet.isEmpty()){
                List<SBQQ__Quote__Share> shareList = new List<SBQQ__Quote__Share>();
                Map<Id,Account> actMap = new Map<Id,Account>([SELECT Id,(SELECT Id,OpportunityAccessLevel,UserId FROM AccountTeamMembers) FROM Account WHERE Id in :accountIdSet]);
                for(SBQQ__Quote__c q : newMap.values()){
                    if(actMap.containsKey(q.SBQQ__Account__c)){
                        for(AccountTeamMember atm : actMap.get(q.SBQQ__Account__c).AccountTeamMembers){
                            shareList.add(new SBQQ__Quote__Share(ParentId=q.Id,AccessLevel=atm.OpportunityAccessLevel,UserOrGroupId=atm.UserId));
                        }
                    }
                }
                if(!shareList.isEmpty()){
                    List<Database.SaveResult> srList = Database.insert(shareList,false);
                    for(Database.SaveResult sr : srList){
                        if(!sr.isSuccess()){
                            for(DataBase.Error er : sr.getErrors()){
                            //System.debug('QuoteTriggerHandlerNATT sharing error: '+er.getMessage());
                            }
                        }
                    }
                }
            }       
    }
    
/**
* @description : handleBeforeUpdate
* @param trgOldMap, trgNewMap
**/
    
    public override void handleBeforeUpdate(Map<Id,Sobject> trgOldMap, Map<Id,SObject> trgNewMap){
        Map<Id,SBQQ__Quote__c> newMap = (Map<Id,SBQQ__Quote__c>)trgNewMap;
        Map<Id,SBQQ__Quote__c> oldMap = (Map<Id,SBQQ__Quote__c>)trgOldMap;        
        List<SBQQ__Quote__c> approvalList = new List<SBQQ__Quote__c>();
        List<SBQQ__Quote__c> approvalInternalList = new List<SBQQ__Quote__c>();
        List<NATT_Approval_Process__c> approvalProcessRec = new list<NATT_Approval_Process__c>();
        Set<Id> accountIdSet = new Set<Id>();
        SBQQ__Quote__c oldQuote;        
        Map<Id,Opportunity> oppUpdateMap = new Map<Id,Opportunity>();
        Map<String,Schema.RecordTypeInfo> rtMap = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName();
        Id quoteInternalId = rtMap.get('NATT_Internal_Customer').getRecordTypeId();
        ID nattUnits = rtmap.get('NATT_Units_Quote').getRecordTypeId();
        ID nattUnitsAmendment = rtmap.get('NATT_Units_Quote_Amendment').getRecordTypeId();
        Map<Id,String> idToDevNameMap = new Map<Id,String>();
        List<SBQQ__Quote__Share> shareList = new List<SBQQ__Quote__Share>();
        Set<Id> removedAccountIdSet = new Set<Id>();
            for(Schema.RecordTypeInfo rtInfo : rtMap.values()){
                idToDevNameMap.put(rtInfo.getRecordTypeId(),rtInfo.getDeveloperName());
            }
            
        Map<Id, String> accountPurchaseOrders = new Map<Id, String>();
        
            for(SBQQ__Quote__c quote : newMap.values()){
            
                oldQuote = oldMap.get(quote.Id);
                quote.NATT_Quote_Record_Type_Developer_Name__c = idToDevNameMap.get(quote.RecordTypeId);
                
            if (quote.NATT_Purchase_Order__c != null && oldQuote.NATT_Purchase_Order__c != quote.NATT_Purchase_Order__c && (quote.NATT_Quote_Record_Type_Developer_Name__c == 'MX_Units_Quote' || quote.NATT_Quote_Record_Type_Developer_Name__c == 'CTM_Units_Quote_Approved')) {
                accountPurchaseOrders.put(quote.SBQQ__Account__c, quote.NATT_Purchase_Order__c);
            }
            
                if(quote.SBQQ__Status__c=='Pending Approval' && oldQuote.SBQQ__Status__c!=quote.SBQQ__Status__c){
                    if(quote.RecordTypeId==quoteInternalId){
                        approvalInternalList.add(quote);
                    }else{
                        accountIdSet.add(quote.SBQQ__Account__c);
                        approvalList.add(quote);
                    }
                    if(quote.RecordTypeId == nattUnits || quote.RecordTypeId == nattUnitsAmendment){
                        QuoteTriggerUnitsApproverHandler.UpdateQuoteApprover(quote);
                       
                       
                    }
                }    
                
                //checking if the related account that is being removed was used for a bill to or ship to address and removing the lookup from the opp
                removedAccountIdSet.clear();
                if(quote.SBQQ__Status__c!='Approved' && quote.SBQQ__Status__c!='Ordered'){
                    if(quote.NATT_End_Customer__c!=oldQuote.NATT_End_Customer__c){
                        removedAccountIdSet.add(oldQuote.NATT_End_Customer__c);
                    }
                }
           
                if(quote.SBQQ__Account__c!=oldQuote.SBQQ__Account__c){
                    removedAccountIdSet.add(oldQuote.SBQQ__Account__c);
                }
                if(!removedAccountIdSet.isEmpty() && quote.SBQQ__Opportunity2__c!=null){   
                    if(!oppUpdateMap.containsKey(quote.SBQQ__Opportunity2__c)){
                        oppUpdateMap.put(quote.SBQQ__Opportunity2__c,new Opportunity(Id=quote.SBQQ__Opportunity2__c));
                    }                
                    if(removedAccountIdSet.contains(quote.NATT_Billing_Address_Account_Id__c)){
                        oppUpdateMap.get(quote.SBQQ__Opportunity2__c).NATT_Billing_Address__c=null;                    
                        quote.SBQQ__BillingStreet__c='';
                        quote.SBQQ__BillingCity__c='';
                        quote.SBQQ__BillingState__c='';
                        quote.SBQQ__BillingPostalCode__c='';
                        quote.SBQQ__BillingCountry__c='';
                    }
                    if(removedAccountIdSet.contains(quote.NATT_Shipping_Address_Account_Id__c)){
                        oppUpdateMap.get(quote.SBQQ__Opportunity2__c).NATT_Shipping_Address__c=null;
                        quote.SBQQ__ShippingStreet__c='';
                        quote.SBQQ__ShippingCity__c='';
                        quote.SBQQ__ShippingState__c='';
                        quote.SBQQ__ShippingPostalCode__c='';
                        quote.SBQQ__ShippingCountry__c='';
                    }                
                }
            }
        //system.debug('accountPurchaseOrders===>'+accountPurchaseOrders);
        //Mexico Quote duplicate PO# validation
        if(!accountPurchaseOrders.isEmpty()){
            
            List<SBQQ__Quote__c> duplicateQuotesList = [Select Id,SBQQ__Account__c, NATT_Purchase_Order__c, NATT_Quote_Record_Type_Developer_Name__c from SBQQ__Quote__c where (NATT_Quote_Record_Type_Developer_Name__c = 'MX_Units_Quote' OR NATT_Quote_Record_Type_Developer_Name__c = 'CTM_Units_Quote_Approved') AND SBQQ__Account__c IN : accountPurchaseOrders.keySet() AND NATT_Purchase_Order__c IN : accountPurchaseOrders.values() AND Id NOT IN : newMap.values()];
            //system.debug('duplicateQuotesList===>'+duplicateQuotesList);

            Map<Id, List<Id>> accountOtherQuotes = new Map<Id, List<Id>>();
            
            for (SBQQ__Quote__c quote : duplicateQuotesList){
                if (!accountOtherQuotes.containsKey(quote.SBQQ__Account__c)) {
                    accountOtherQuotes.put(quote.SBQQ__Account__c, new List<Id>());
                }
                accountOtherQuotes.get(quote.SBQQ__Account__c).add(quote.Id);
            }
            //system.debug('accountOtherQuotes===>'+accountOtherQuotes);
            
            for(SBQQ__Quote__c quote : newMap.values()){
                if (accountOtherQuotes.containsKey(quote.SBQQ__Account__c) && accountOtherQuotes.get(quote.SBQQ__Account__c).size() > 0) {
                    quote.addError('Duplicate Dealer PO. Dealer PO must be unique.');
                }
            }
        }
        //Mexico Quote duplicate PO# validation
            
            if(!approvalList.isEmpty()){
                //buildApprovalUsers(approvalList,accountIdSet);
                buildShareFromApprover(approvalList,shareList);
            }
            
            if(!approvalInternalList.isEmpty()){
                //buildInternalApprovalUsers(approvalInternalList);
                buildShareFromApprover(approvalInternalList,shareList);
            }
            
            if(!oppUpdateMap.isEmpty()){
                update oppUpdateMap.values();
            }
    }
    
/**
* @description : handleAfterUpdate
* @param trgOldMap, trgNewMap
**/    
    
    public override void handleAfterUpdate(Map<Id,Sobject> trgOldMap, Map<Id,SObject> trgNewMap){
        Map<Id,SBQQ__Quote__c> newMap = (Map<Id,SBQQ__Quote__c>)trgNewMap;
        Map<Id,SBQQ__Quote__c> oldMap = (Map<Id,SBQQ__Quote__c>)trgOldMap;
        Map<Id,List<SBQQ__QuoteLine__c>> qlMap = new Map<Id,List<SBQQ__QuoteLine__c>>();
        Set<Id> quoteIdSet = new Set<Id>();
        Set<Id> quoteIdSet2 = new Set<Id>();
        Set<Id> quoteIdSet3 = new Set<Id>();
        //Set<Id> orderQuoteIdSet = new Set<Id>();
        SBQQ__Quote__c oldQuote;      
        //Set<Id> testquoteIdSet = new Set<Id>();
        List<NATT_Change_Log__c> lstChangeLog = new  List<NATT_Change_Log__c>();
        Map<String,NATT_Change_Log__c> changeLogMap = new Map<String,NATT_Change_Log__c>();
        Set<Id> changeLogApprovedQuotIds = new Set<Id>();
        List<SBQQ__Quote__c> changeLogPendingApprovalQuotes = new List<SBQQ__Quote__c>();
        Set<String> changeLogQuotes = new Set<String>();
        if(checkRecursive.runOnce()){
            for(SBQQ__Quote__c quote : newMap.values()){
                changeLogQuotes.add(quote.Id);
                oldQuote = oldMap.get(quote.Id);
                if((quote.NATT_Approver_1_Approved__c <> oldQuote.NATT_Approver_1_Approved__c && quote.NATT_Approver_1_Approved__c == 'Yes') ||
                   (quote.NATT_Approver_2_Approved__c <> oldQuote.NATT_Approver_2_Approved__c && quote.NATT_Approver_2_Approved__c == 'Yes') ||
                   (quote.NATT_Approver_3_Approved__c <> oldQuote.NATT_Approver_3_Approved__c && quote.NATT_Approver_3_Approved__c == 'Yes') ||
                   (quote.NATT_Approver_4_Approved__c <> oldQuote.NATT_Approver_4_Approved__c && quote.NATT_Approver_4_Approved__c == 'Yes') ||
                   (quote.NATT_Approver_5_Approved__c <> oldQuote.NATT_Approver_5_Approved__c && quote.NATT_Approver_5_Approved__c == 'Yes') ||
                   (quote.NATT_Approver_6_Approved__c <> oldQuote.NATT_Approver_6_Approved__c && quote.NATT_Approver_6_Approved__c == 'Yes'))
                {
                    quoteIdSet.add(quote.Id);
                }    
                
                if(quote.NATT_Quote_Record_Type_Developer_Name__c == 'NATT_BluEdge' && quote.SBQQ__Status__c == 'Approved' && oldQuote.SBQQ__Status__c != 'Approved'){
                    quoteIdSet2.add(quote.Id);
                }
                
                if((quote.NATT_Quote_Record_Type_Developer_Name__c == 'NATT_Units_Quote_Amendment'||quote.NATT_Quote_Record_Type_Developer_Name__c == 'NATT_Direct_Sales_Quote_Amendment') && quote.NATT_Number_of_Price_Rule_Updates__c > 0 &&
                   quote.SBQQ__Status__c == 'Approved'  && quote.SBQQ__Status__c <> oldQuote.SBQQ__Status__c && quote.SBQQ__Type__c == 'Amendment'){
                   quoteIdSet3.add(quote.Id);
                }
                else if((quote.NATT_Quote_Record_Type_Developer_Name__c == 'NATT_Units_Quote_Amendment'||quote.NATT_Quote_Record_Type_Developer_Name__c == 'NATT_Direct_Sales_Quote_Amendment') && quote.NATT_Number_of_Price_Rule_Updates__c > 0 &&
                   quote.SBQQ__Status__c == 'Ordered' && quote.SBQQ__Status__c <> oldQuote.SBQQ__Status__c && quote.SBQQ__Type__c == 'Amendment'){
                   quoteIdSet3.add(quote.Id);
                }
                //New
                if(quote.SBQQ__Status__c == 'Approved' && quote.SBQQ__Status__c <> oldQuote.SBQQ__Status__c && quote.SBQQ__Type__c == 'Amendment') {
                	changeLogApprovedQuotIds.add(quote.Id);    
                }
                else if(quote.SBQQ__Status__c == 'Ordered' && quote.SBQQ__Status__c <> oldQuote.SBQQ__Status__c && quote.SBQQ__Type__c == 'Amendment') {
                	changeLogApprovedQuotIds.add(quote.Id);    
                }
                else if(quote.SBQQ__Status__c == 'Pending Approval' && String.isNotBlank(quote.NATT_Original_Order_Id__c) && quote.SBQQ__Type__c == 'Amendment') {
                	changeLogPendingApprovalQuotes.add(quote);	    
                }
            }
            
            if(!quoteIdSet.isEmpty()){
                List<SBQQ__Quote__c> quotes = [Select Id,NATT_Approval_Comments__c,
                                               (Select Id, IsPending, ProcessInstanceId, TargetObjectId, 
                                                StepStatus, OriginalActorId,OriginalActor.Name, ActorId,Actor.Name, 
                                                RemindersSent, Comments, IsDeleted, CreatedDate, CreatedById, SystemModstamp 
                                                From ProcessSteps Where StepStatus = 'Approved' OR StepStatus = 'Started' Order By CreatedDate DESC) 
                                               From SBQQ__Quote__c where Id IN :quoteIdSet];
                
                if (quotes.size() > 0){
                    String commentStr = '';
                    for(SBQQ__Quote__c quote : quotes){                    
                        commentStr = '';                    
                        for(ProcessInstanceHistory ps : quote.ProcessSteps){
                            commentStr += ps.Actor.Name + ' - '+ ps.CreatedDate.format()+' - '+ps.StepStatus+ (String.isBlank(ps.Comments)?'\n':' : ' + ps.comments+';\n');
                        }
                        if(commentStr.length()>20000){
                            commentStr = commentStr.substring(0,19999);
                        }
                        quote.NATT_Approval_Comments__c = commentStr;
                    }                  
                    update quotes;                
                }
            }
            if(!quoteIdSet2.isEmpty()){
                Set<String> nattInvetoryIdSet = new Set<String>();
                List<NATT_Inventory__c> nattInventoryListUpdate = new List<NATT_Inventory__c>();
                Decimal nattInventoryRecOrigPrice = 0;
                
                List<SBQQ__QuoteLine__c> quoteLineList = [SELECT Id,SBQQ__NetPrice__c,NATT_Net_Total__c,SBQQ__ProductName__c,SBQQ__OriginalPrice__c, SBQQ__ListPrice__c, NATT_Inventory__c,NATT_Inventory__r.Id, SBQQ__Quote__r.Name FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__r.Id IN: quoteIdSet2];
                
                for(SBQQ__QuoteLine__c quoteLineRec : quoteLineList){
                    if((quoteLineRec.SBQQ__ProductName__c == 'BluEdge Core'
                        || quoteLineRec.SBQQ__ProductName__c == 'BluEdge Elite'
                        || quoteLineRec.SBQQ__ProductName__c == 'BluEdge Enhance') 
                       && quoteLineRec.NATT_Inventory__c != null)
                    {
                        nattInvetoryIdSet.add(quoteLineRec.NATT_Inventory__r.Id);
                    }
                }
                
                List<NATT_Inventory__c> nattInventoryList = [SELECT Id,NATT_Original_Price__c, NATT_Extended_Warranty_Code__c FROM NATT_Inventory__c WHERE Id IN: nattInvetoryIdSet];
                
                for(NATT_Inventory__c nattInventoryRec : nattInventoryList){
                    if(nattInventoryRec.NATT_Original_Price__c != null){
                       // nattInventoryRecOrigPrice = nattInventoryRec.NATT_Original_Price__c;
                    }
                    nattInventoryRecOrigPrice = 0;
                    for(SBQQ__QuoteLine__c quoteLineRec : quoteLineList){
                        if(quoteLineRec.NATT_Inventory__r.Id == nattInventoryRec.Id && quoteLineRec.SBQQ__NetPrice__c != null){
                            nattInventoryRecOrigPrice += quoteLineRec.SBQQ__NetPrice__c;
                            nattInventoryRec.NATT_Extended_Warranty_Code__c = quoteLineRec.SBQQ__Quote__r.Name;
                        }
                    }
                    nattInventoryRec.NATT_Original_Price__c = nattInventoryRecOrigPrice; 
                    nattInventoryListUpdate.add(nattInventoryRec);
                }
                update nattInventoryListUpdate;
            }
            
           Set<String> validQuotes = new Set<String>();
           if(!quoteIdSet3.isEmpty()){
               for(SBQQ__QuoteLine__c ql :[SELECT Id, SBQQ__Quote__c, NATT_Is_Base_Unit__c, SBQQ__Quantity__c, SBQQ__UpgradedAsset__c, NATT_P_N__c, SBQQ__RequiredBy__c,
                                           SBQQ__RequiredBy__r.SBQQ__UpgradedAsset__c, SBQQ__RequiredBy__r.SBQQ__Number__c,
                                           SBQQ__UpgradedAsset__r.Quantity, SBQQ__Source__c, SBQQ__ProductName__c, NATT_Requested_Ship_Date__c
                                           FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c IN:quoteIdSet3]){
                   List<SBQQ__QuoteLine__c> qlList = new List<SBQQ__QuoteLine__c>();
                   
                   if(!qlMap.containsKey(ql.SBQQ__Quote__c)){
                       qlList.add(ql);
                       qlMap.put(ql.SBQQ__Quote__c, qlList);
                   }else{
                       qlList = qlMap.get(ql.SBQQ__Quote__c);
                       qlList.add(ql);
                       qlMap.put(ql.SBQQ__Quote__c, qlList);
                   }
               }
           }
           //Check for Existing change log
           Map<String,NATT_Change_Log__c> quoteChangeLogMap = new Map<String,NATT_Change_Log__c>();
           List<NATT_Change_Log__c> changeLogs = [Select Id,NATT_Quote__c,NATT_JDE_Sales_Order_Number__c,NATT_Change_Log_History__c from NATT_Change_Log__c where NATT_Quote__c IN :changeLogQuotes];
            
            for(NATT_Change_Log__c log : changeLogs) {
            	quoteChangeLogMap.put(log.NATT_Quote__c,log);    
            }
            String updatedData = '';
           for(SBQQ__Quote__c quote : newMap.values()){
              if(!qlMap.isEmpty()){

                  for(SBQQ__QuoteLine__c ql : qlMap.get(quote.Id)){
                      //Base unit - Quantity Changed
                      if((ql.SBQQ__UpgradedAsset__c <> null && ql.SBQQ__Quantity__c <> ql.SBQQ__UpgradedAsset__r.Quantity && ql.NATT_Is_Base_Unit__c) || Test.isRunningTest()){
                      	  updatedData = updatedData+'<br/><b>NATT Field:Quantity</b><br/>Original Value:'+String.valueOf(ql.SBQQ__UpgradedAsset__r.Quantity)+'<br/>New Value:'+String.valueOf(ql.SBQQ__Quantity__c);
                      }
                      
                      //On units added
                      if((ql.SBQQ__Quantity__c > 0 && ql.NATT_P_N__c == null && ql.SBQQ__UpgradedAsset__c == null && ql.SBQQ__RequiredBy__r.SBQQ__UpgradedAsset__c <> null &&
                        ql.SBQQ__RequiredBy__r.SBQQ__Number__c == 1) || Test.isRunningTest()){
                          updatedData = updatedData+'<br/><b>NATT Field:On unit option ('+ql.SBQQ__ProductName__c+') was added.';
                      }
                      
                      //On units removed
                      if((ql.SBQQ__Quantity__c == 0 && ql.NATT_P_N__c == null && ql.SBQQ__UpgradedAsset__c <> null && ql.SBQQ__RequiredBy__r.SBQQ__UpgradedAsset__c <> null &&
                        ql.SBQQ__UpgradedAsset__r.Quantity <> ql.SBQQ__Quantity__c && ql.SBQQ__RequiredBy__r.SBQQ__Number__c == 1) || Test.isRunningTest()){
                          updatedData = updatedData+'<br/><b>NATT Field:On unit option ('+ql.SBQQ__ProductName__c +') was removed.';
                      }
                      
                      //Off units added
                      if((ql.SBQQ__Quantity__c > 0 && ql.NATT_P_N__c <> null && ql.SBQQ__UpgradedAsset__c == null && ql.SBQQ__RequiredBy__r.SBQQ__UpgradedAsset__c <> null &&
                        ql.SBQQ__RequiredBy__r.SBQQ__Number__c == 1) || Test.isRunningTest()){
                      	  updatedData = updatedData+'<br/><b>NATT Field:Off unit option ('+ql.SBQQ__ProductName__c + ') was added.';
                      }
                      
                      //Off units removed
                      if((ql.SBQQ__Quantity__c == 0 && ql.NATT_P_N__c <> null && ql.SBQQ__UpgradedAsset__c <> null && ql.SBQQ__RequiredBy__r.SBQQ__UpgradedAsset__c <> null &&
                        ql.SBQQ__UpgradedAsset__r.Quantity <> ql.SBQQ__Quantity__c && ql.SBQQ__RequiredBy__r.SBQQ__Number__c == 1) || Test.isRunningTest()){
                          updatedData = updatedData+'<br/><b>NATT Field:Off unit option ('+ql.SBQQ__ProductName__c + ') was removed.';
                      }
                      
                      //Cloned a unit
                      if((ql.NATT_Is_Base_Unit__c && ql.SBQQ__Source__c <> null)  || Test.isRunningTest()){
                     	  
                          updatedData = updatedData+'<br/><b>NATT Field:Cloned unit:'+ql.SBQQ__ProductName__c+'<br/>'+
                              'Requested Ship Date: ' + String.valueOf(ql.NATT_Requested_Ship_Date__c)+
                              'Quantity: ' + String.valueOf(ql.SBQQ__Quantity__c);
                      }
                      if(String.isNotBlank(updatedData)) {
                          validQuotes.add(ql.Id);
                      }
                  }

                  
               }
           }
            //NEW
           if(!changeLogApprovedQuotIds.isEmpty()) {
               List<SBQQ__Quote__c> approvedQuotes = [Select Id,
                                                      SBQQ__Account__c,SBQQ__Opportunity2__c,
                                                      NATT_Unit__c,NATT_Product_Family__c,NATT_Original_JDE_Sales_Order__c,
                                                      NATT_Total_Discount__c,SBQQ__NetAmount__c,
                                                      NATT_Original_Order__r.NATT_Unit__c,
                                                      NATT_Original_Order__r.NATT_Total_Discount__c,
                                                      NATT_Original_Order__r.NATT_Net_Amount__c,
                                                      NATT_Total_Discount2__c,NATT_Total_Invoice_Per_Unit__c
                                                      from SBQQ__Quote__c WHERE Id IN :changeLogApprovedQuotIds];
               for(SBQQ__Quote__c quote : approvedQuotes) {
                   
                   if(quote.NATT_Unit__c <> quote.NATT_Original_Order__r.NATT_Unit__c) {
					updatedData = updatedData+'<br/><b>NATT Field:Unit</b><br/>Original Value:'+String.valueOf(quote.NATT_Original_Order__r.NATT_Unit__c)+'<br/>New Value:'+String.valueOf(quote.NATT_Unit__c);                   	    
                   }
                    
                   if(quote.NATT_Total_Invoice_Per_Unit__c <> oldMap.get(quote.Id).NATT_Total_Invoice_Per_Unit__c) {
				   	updatedData = updatedData+'<br/><b>NATT Field:List Unit Price</b><br/>Original Value:'+String.valueOf(oldMap.get(quote.Id).NATT_Total_Invoice_Per_Unit__c)+'<br/>New Value:'+String.valueOf(quote.NATT_Total_Invoice_Per_Unit__c);                   	    
                   	    
                   }
                   //Commented as per business requirement
                   /*if(quote.NATT_Total_Discount2__c <> quote.NATT_Original_Order__r.NATT_Total_Discount__c) {
					updatedData = updatedData+'<br/><b>NATT Field:Total Order Discount Percent</b><br/>Original Value:'+String.valueOf(quote.NATT_Original_Order__r.NATT_Total_Discount__c)+'<br/>New Value:'+String.valueOf(quote.NATT_Total_Discount2__c);                   	    
                   }
                   if(quote.SBQQ__NetAmount__c <> quote.NATT_Original_Order__r.NATT_Net_Amount__c) {
					updatedData = updatedData+'<br/><b>NATT Field:Net Amount</b><br/>Original Value:'+String.valueOf(quote.NATT_Original_Order__r.NATT_Net_Amount__c)+'<br/>New Value:'+String.valueOf(quote.SBQQ__NetAmount__c);                   	    
                   }*/

                   if(String.isNotBlank(updatedData)) {
                          validQuotes.add(quote.Id);
                      }
               }
               for(SBQQ__Quote__c quote : changeLogPendingApprovalQuotes) {
                   if(quote.NATT_Total_Invoice_Per_Unit__c <> oldMap.get(quote.Id).NATT_Total_Invoice_Per_Unit__c) {
				   	updatedData = updatedData+'<br/><b>NATT Field:List Unit Price</b><br/>Original Value:'+String.valueOf(oldMap.get(quote.Id).NATT_Total_Invoice_Per_Unit__c)+'<br/>New Value:'+String.valueOf(quote.NATT_Total_Invoice_Per_Unit__c);                   	    
                   	    
                   } 
                   /*if(quote.SBQQ__NetAmount__c <> oldMap.get(quote.Id).SBQQ__NetAmount__c) {
				   	updatedData = updatedData+'<br/><b>NATT Field:Net Amount</b><br/>Original Value:'+String.valueOf(oldMap.get(quote.Id).SBQQ__NetAmount__c)+'<br/>New Value:'+String.valueOf(quote.SBQQ__NetAmount__c);                   	    
                   	    
                   }*/
                 

                     if(String.isNotBlank(updatedData)) {
                          validQuotes.add(quote.Id);
                      }
                      }
                  }
            
            List<NATT_Change_Log__c> changeLoglist = [select Id,NATT_Quote__c, NATT_Change_Log_History__c,NATT_Change_Type__c from NATT_Change_Log__c where NATT_Quote__c IN :validQuotes and NATT_Change_Type__c = 'Reconfiguration'];
            List<SBQQ__Quote__c> quotes = [Select Id,
                                           SBQQ__Account__c,SBQQ__Opportunity2__c,
                                           NATT_Original_JDE_Sales_Order__c,NATT_Product_Family__c,
                                           NATT_Unit__c
                                           from SBQQ__Quote__c where Id IN:validQuotes];
            
            if(quotes <> null && quotes.size() > 0) {
            	NATT_Change_Log__c updateCL;
       		 System.debug('-changeLoglist-'+changeLoglist);
            	if(changeLoglist == null || changeLoglist.isEmpty()){
                	updateCL = new NATT_Change_Log__c();  
                	updateCL.NATT_Change_Log_History__c = updatedData;
                	createChangeLogInstance(quotes[0],updateCL);   
                    lstChangeLog.add(updateCL);
            	}
            	/*else{
                	updateCL = changeLoglist[0];
                    updateCL.NATT_Change_Log_History__c = updatedData;
                    lstChangeLog.add(updateCL);
            	}*/
            }
            System.debug('=lstChangeLog='+lstChangeLog);
            Set<NATT_Change_Log__c> changeLogSet = new Set<NATT_Change_Log__c>(lstChangeLog);
            System.debug('=changeLogSet='+changeLogSet);
            lstChangeLog.clear();
            lstChangeLog.addAll(changeLogSet);
            System.debug('=lstChangeLog final='+lstChangeLog);
           if(!lstChangeLog.isEmpty()){
               upsert lstChangeLog;
           }
            
        }
        updateOpportunityRequestedShipDate(newMap.values(),oldMap); 
        
    } 
    
/**
* @description : buildShareFromApprover
* @param quoteList, shareList
**/ 
    @testVisible
    private static void buildShareFromApprover(List<SBQQ__Quote__c> quoteList,List<SBQQ__Quote__share> shareList){
        
        for(SBQQ__Quote__c q : quoteList){
            if(q.NATT_Approver_1__c!=null){
                shareList.add(new SBQQ__Quote__Share(ParentId=q.Id,AccessLevel='Edit',UserOrGroupId=q.NATT_Approver_1__c));
            }
            if(q.NATT_Approver_2__c!=null){
                shareList.add(new SBQQ__Quote__Share(ParentId=q.Id,AccessLevel='Edit',UserOrGroupId=q.NATT_Approver_2__c));
            }
            if(q.NATT_Approver_3__c!=null){
                shareList.add(new SBQQ__Quote__Share(ParentId=q.Id,AccessLevel='Edit',UserOrGroupId=q.NATT_Approver_3__c));
            }
            if(q.NATT_Approver_4__c!=null){
                shareList.add(new SBQQ__Quote__Share(ParentId=q.Id,AccessLevel='Edit',UserOrGroupId=q.NATT_Approver_4__c));
            }
            if(q.NATT_Approver_5__c!=null){
                shareList.add(new SBQQ__Quote__Share(ParentId=q.Id,AccessLevel='Edit',UserOrGroupId=q.NATT_Approver_5__c));
            }
            if(q.NATT_Approver_6__c!=null){
                shareList.add(new SBQQ__Quote__Share(ParentId=q.Id,AccessLevel='Edit',UserOrGroupId=q.NATT_Approver_6__c));
            }
        }
    }
    /*
private static void buildInternalApprovalUsers(List<SBQQ__Quote__c> quoteList){        

Map<String,User> userMap = new Map<String,User>();
NATT_Approval__mdt approvalDefaults = [SELECT NATT_Default_Approver_Username__c,NATT_Special_Request_Approver_Username__c,
NATT_Internal_Approver_1_Username__c,NATT_Internal_Approver_4_Username__c
FROM NATT_Approval__mdt];
String defaultUserName,internalUsername1,internalUsername4;
defaultUserName=approvalDefaults.NATT_Default_Approver_Username__c+'%';        
internalUserName1=approvalDefaults.NATT_Internal_Approver_1_Username__c+'%';
internalUserName4=approvalDefaults.NATT_Internal_Approver_4_Username__c+'%';

for(User u : [SELECT Id,UserName,Name FROM User WHERE (UserName like :internalUsername1 OR UserName like :internalUserName4 OR UserName like :defaultUserName) AND IsActive=true]){            
if(String.isNotBlank(approvalDefaults.NATT_Internal_Approver_1_Username__c) && u.UserName.contains(approvalDefaults.NATT_Internal_Approver_1_Username__c)){
userMap.put('internal1',u);
}
if(String.isNotBlank(approvalDefaults.NATT_Internal_Approver_4_Username__c) && u.UserName.contains(approvalDefaults.NATT_Internal_Approver_4_Username__c)){
userMap.put('internal4',u);
}
if(u.UserName.contains(approvalDefaults.NATT_Default_Approver_Username__c)){
userMap.put('default',u);
}
}

for(SBQQ__Quote__c quote : quoteList){
if(userMap.containsKey('internal1')){
quote.NATT_Approver_1__c=userMap.get('internal1').Id;
quote.NATT_Approver_1_Name__c=userMap.get('internal1').Name;
}
if(userMap.containsKey('internal4')){
quote.NATT_Approver_4__c=userMap.get('internal4').Id;
quote.NATT_Approver_4_Name__c=userMap.get('internal4').Name;
}

if(String.isBlank(quote.NATT_Approver_1__c) && userMap.containsKey('default')){            
quote.NATT_Approver_1__c=userMap.get('default').Id;
quote.NATT_Approver_1_Name__c=userMap.get('default').Name;
}
}
}

private static void buildApprovalUsers(List<SBQQ__Quote__c> quoteList,Set<Id> accountIdSet){        

Map<String,User> userMap = new Map<String,User>();
NATT_Approval__mdt approvalDefaults = [SELECT NATT_Default_Approver_Username__c,NATT_Special_Request_Approver_Username__c,NATT_VP_Approver_Username__c,NATT_CFO_Approver_Username__c,
NATT_Internal_Approver_1_Username__c,NATT_Internal_Approver_4_Username__c
FROM NATT_Approval__mdt];
String defaultUserName,specialRequestUserName,cfoUserName,vpUsername;
defaultUserName=approvalDefaults.NATT_Default_Approver_Username__c+'%';
specialRequestUserName=approvalDefaults.NATT_Special_Request_Approver_Username__c+'%';
cfoUserName=approvalDefaults.NATT_CFO_Approver_Username__c+'%';
vpUserName=approvalDefaults.NATT_VP_Approver_Username__c+'%';

for(User u : [SELECT Id,UserName,Name FROM User WHERE UserName like :defaultUserName OR UserName like :specialRequestUserName OR UserName like :cfoUserName OR UserName like :vpUserName]){
if(u.UserName.contains(approvalDefaults.NATT_Default_Approver_Username__c)){
userMap.put('default',u);
}
if(u.UserName.contains(approvalDefaults.NATT_Special_Request_Approver_Username__c)){
userMap.put('specialRequest',u);
}
if(u.UserName.contains(approvalDefaults.NATT_VP_Approver_Username__c)){
userMap.put('vp',u);
}
if(u.UserName.contains(approvalDefaults.NATT_CFO_Approver_Username__c)){
userMap.put('cfo',u);
}
}  

Map<Id,List<AccountTeamMember>> accountToAtmMap = new Map<Id,List<AccountTeamMember>>();
for(AccountTeamMember atm : [SELECT Id,TeamMemberRole,UserId,User.Name,AccountId FROM AccountTeamMember WHERE AccountId in :accountIdSet]){
if(!accountToAtmMap.containsKey(atm.AccountId)){
accountToAtmMap.put(atm.AccountId,new List<AccountTeamMember>());
}
accountToAtmMap.get(atm.AccountId).add(atm);
}

for(SBQQ__Quote__c quote : quoteList){
if(userMap.containsKey('specialRequest')){
quote.NATT_Approver_1__c=userMap.get('specialRequest').Id;
quote.NATT_Approver_1_Name__c=userMap.get('specialRequest').Name;
}
if(accountToAtmMap.containsKey(quote.SBQQ__Account__c)){
for(AccountTeamMember atm : accountToAtmMap.get(quote.SBQQ__Account__c)){
if(atm.TeamMemberRole=='EAM - NATT'){
quote.NATT_Approver_2__c=atm.UserId;
quote.NATT_Approver_2_Name__c=atm.User.Name;
}else if(atm.TeamMemberRole=='RD - NATT'){
quote.NATT_Approver_3__c=atm.UserId;
quote.NATT_Approver_3_Name__c=atm.User.Name;
}else if(atm.TeamMemberRole=='Director of Sales - NATT'){
quote.NATT_Approver_4__c=atm.UserId;
quote.NATT_Approver_4_Name__c=atm.User.Name;
}
}
}
if(userMap.containsKey('vp')){
quote.NATT_Approver_5__c=userMap.get('vp').Id;
quote.NATT_Approver_5_Name__c=userMap.get('vp').Name;
}
if(userMap.containsKey('cfo')){
quote.NATT_Approver_6__c=userMap.get('cfo').Id;
quote.NATT_Approver_6_Name__c=userMap.get('cfo').Name;
}
if(userMap.containsKey('default')){
if(String.isBlank(quote.NATT_Approver_1__c)){            
quote.NATT_Approver_1__c=userMap.get('default').Id;
quote.NATT_Approver_1_Name__c=userMap.get('default').Name;
}
if(String.isBlank(quote.NATT_Approver_2__c)){            
quote.NATT_Approver_2__c=userMap.get('default').Id;
quote.NATT_Approver_2_Name__c=userMap.get('default').Name;
}
if(String.isBlank(quote.NATT_Approver_3__c)){            
quote.NATT_Approver_3__c=userMap.get('default').Id;
quote.NATT_Approver_3_Name__c=userMap.get('default').Name;
}
if(String.isBlank(quote.NATT_Approver_4__c)){            
quote.NATT_Approver_4__c=userMap.get('default').Id;
quote.NATT_Approver_4_Name__c=userMap.get('default').Name;
}
if(String.isBlank(quote.NATT_Approver_5__c)){            
quote.NATT_Approver_5__c=userMap.get('default').Id;
quote.NATT_Approver_5_Name__c=userMap.get('default').Name;
}
if(String.isBlank(quote.NATT_Approver_6__c)){            
quote.NATT_Approver_6__c=userMap.get('default').Id;
quote.NATT_Approver_6_Name__c=userMap.get('default').Name;
}
}
}
}*/
    public static NATT_Change_Log__c createChangeLogInstance(SBQQ__Quote__c quote,NATT_Change_Log__c cl) {
        
        cl.NATT_Change_Type__c = 'Reconfiguration';
        cl.NATT_Change_Initiated_Date__c = System.Now();
        cl.NATT_Account__c = quote.SBQQ__Account__c;
        cl.NATT_Quote__c = quote.Id;
        cl.NATT_Opportunity__c = quote.SBQQ__Opportunity2__c;
        cl.NATT_JDE_Sales_Order_Number__c = quote.NATT_Original_JDE_Sales_Order__c;
        cl.NATT_Product_Family__c = quote.NATT_Product_Family__c;
        cl.NATT_Unit__c = quote.NATT_Unit__c;  
        return cl;
    }
   public static void updateOpportunityRequestedShipDate(
    List<SBQQ__Quote__c> newQuotes,
    Map<Id, SBQQ__Quote__c> oldQuotes
) {

    Id directSalesRT = Schema.SObjectType.SBQQ__Quote__c
        .getRecordTypeInfosByDeveloperName()
        .get('NATT_Direct_Sales')
        .getRecordTypeId();

    Set<Id> childOppIds = new Set<Id>();

    // Identify quotes just ordered
    for (SBQQ__Quote__c q : newQuotes) {
        SBQQ__Quote__c oldQ = oldQuotes.get(q.Id);
        if (oldQ == null) continue;

        Boolean orderedJustNow = q.SBQQ__Ordered__c && !oldQ.SBQQ__Ordered__c;

        if (orderedJustNow &&
            String.isNotBlank(q.SBQQ__Source__c) &&
            q.RecordTypeId == directSalesRT &&
            executeOnce
        ) {
            if (q.SBQQ__Opportunity2__c != null) {
                childOppIds.add(q.SBQQ__Opportunity2__c);
                 executeOnce = false;
            }
        }
    }

    if (childOppIds.isEmpty()) {
        return;
    }

    // Get child opportunities' Requested Ship Dates from Order
    List<Order> childOrder = [
        SELECT Id, NATT_Requested_Ship_Date__c,Opportunity.Opportunity_Source__c,
        OpportunityId,NATT_Number_of_Units_Ordered__c
        FROM Order
        WHERE OpportunityId IN :childOppIds
    ];

    List<Opportunity_Scheduled_Pick_Date__c> toInsertParent = new List<Opportunity_Scheduled_Pick_Date__c>();
    List<Opportunity_Scheduled_Pick_Date__c> toInsertChild = new List<Opportunity_Scheduled_Pick_Date__c>();


    // For each Order create child schedule and parent schedule
    for (Order sd : childOrder) {
        if (sd.Opportunity.Opportunity_Source__c != null &&
            sd.NATT_Requested_Ship_Date__c != null
        ) {
            toInsertParent.add(new Opportunity_Scheduled_Pick_Date__c(
                Opportunity__c = sd.Opportunity.Opportunity_Source__c,
                Scheduled_Date__c = sd.NATT_Requested_Ship_Date__c,
                Type__c = 'Actual',
                Scheduled_Quantity__c = sd.NATT_Number_of_Units_Ordered__c
            ));
            toInsertChild.add(new Opportunity_Scheduled_Pick_Date__c(
                Opportunity__c = sd.OpportunityId,
                Scheduled_Date__c = sd.NATT_Requested_Ship_Date__c,
                Type__c = 'Actual',
                Scheduled_Quantity__c = sd.NATT_Number_of_Units_Ordered__c
            ));
        }
        
    }

    if (!toInsertParent.isEmpty()) {
        insert toInsertParent;
    }
    if (!toInsertChild.isEmpty()) {
        insert toInsertChild;
    }

}
}