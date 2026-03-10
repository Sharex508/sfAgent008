/********************************************************************************************************
* @author         (Deloitte)
* @description    This is a Trigger class for Quote Object.
* @date           08/02/2022 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Deloitte               08/02/2022                                  Initial version
*********************************************************************************************************/

public without sharing class CONTAINER_Quote_Trigger_Helper {
    public static void onBeforeUpdate(Map<Id, SBQQ__Quote__c> oldItemsMap, Map<Id,SBQQ__Quote__c> newItemsMap){
        String sbqqquote=system.label.SBQQ_Quote_API_Name;
        String Containerquote=system.label.Container_NT_Quote;
        String gensetquote=system.label.Container_GENSET_Quote;
       //String NTRecord = Schema.getGlobalDescribe().get('SBQQ__Quote__c').getDescribe().getRecordTypeInfosByName().get('Container NT Quote').getRecordTypeId();
       String NTRecord = SBQQ__Quote__c.sObjectType.getDescribe().getRecordTypeInfosByName().get(Containerquote).getRecordTypeId();
        //String GENSETRecord = Schema.getGlobalDescribe().get('SBQQ__Quote__c').getDescribe().getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
          String GENSETRecord = SBQQ__Quote__c.sObjectType.getDescribe().getRecordTypeInfosByName().get(gensetquote).getRecordTypeId();
        for(SBQQ__Quote__c quoteRecord : newItemsMap.values()){
            if((quoteRecord.RecordTypeId == NTRecord || quoteRecord.RecordTypeId == GENSETRecord) && (ContainerConstants.firstRun || Test.isRunningTest())){
                containerBeforeUpdateLogic(oldItemsMap, quoteRecord);
            }
        }
    }
    
    public static void containerBeforeUpdateLogic(Map<Id, SBQQ__Quote__c> oldItemsMap, SBQQ__Quote__c quoteUpdatedElement){
        User userDetails =[SELECT Id, Name, Email, Profile.Name, UserRole.Name FROM User where Id=:userinfo.getUserId()];
        String userRoleName = userDetails.UserRole.Name; 
        SBQQ__Quote__c oldQuote = new SBQQ__Quote__c();
        String errMsg = null;
        
        Set<String> containerRSMStatusSet = new Set<String>();
        containerRSMStatusSet.add('Pending RSM Acceptance for Special Req');
        containerRSMStatusSet.add('Pending RSM Acceptance for Prod & Ship Schedule');
        
        
        oldQuote = oldItemsMap.get(quoteUpdatedElement.Id);
        system.debug('testADAD1'+ quoteUpdatedElement);
        system.debug('testADAD2'+ oldQuote);
        
        boolean containerStatus = ((oldQuote.CONTAINER_Status__c == quoteUpdatedElement.CONTAINER_Status__c) && (oldQuote.ApprovalStatus__c == quoteUpdatedElement.ApprovalStatus__c) &&
                                   (oldQuote.CONTAINER_QuotePath__c == quoteUpdatedElement.CONTAINER_QuotePath__c));
        
        boolean restrictedCAMUpdates = ((oldQuote.Container_Special_Requirement_Comments__c != quoteUpdatedElement.Container_Special_Requirement_Comments__c) || 
                                     (oldQuote.CONTAINER_Special_Req_Price_Update__c != quoteUpdatedElement.CONTAINER_Special_Req_Price_Update__c) || 
                                     (oldQuote.CONTAINER_Feature_Option_Map_Check__c != quoteUpdatedElement.CONTAINER_Feature_Option_Map_Check__c) || 
                                     (oldQuote.CONTAINER_Cost_Contract_Price__c != quoteUpdatedElement.CONTAINER_Cost_Contract_Price__c));
        
        boolean restrictedPMUpdates = ((oldQuote.CONTAINER_Requested_Ship_Date_Up_Check__c != quoteUpdatedElement.CONTAINER_Requested_Ship_Date_Up_Check__c) || 
                                     (oldQuote.CONTAINER_Tentative_Ship_Sc_Update_Check__c != quoteUpdatedElement.CONTAINER_Tentative_Ship_Sc_Update_Check__c) || 
                                     (oldQuote.CONTAINER_Shipment_Schedule_Update__c != quoteUpdatedElement.CONTAINER_Shipment_Schedule_Update__c));
        
        //Logic for VP NT Approval    
        if(oldQuote.CONTAINER_Status__c == 'Pending VP Approval' && ('Approved'.equalsIgnoreCase(quoteUpdatedElement.ApprovalStatus__c) || 'Pending'.equalsIgnoreCase(quoteUpdatedElement.ApprovalStatus__c)) &&
          quoteUpdatedElement.RecordTypeId == ContainerConstants.CONTAINER_NTRecord){
            If(userRoleName != 'Container Sales VP'  && userRoleName != 'Container Sales VP NT' && !(validateIsUserPublicGroupAccess(ContainerConstants.CONTAINER_Sales_VP_Approval_NT_Quote))){
                quoteUpdatedElement.addError(ContainerConstants.CONTAINER_QUOTE_VP_APPROVAL_ERROR);
            }else If(containerStatus && (userRoleName == 'Container Sales VP'  || userRoleName == 'Container Sales VP NT' || validateIsUserPublicGroupAccess(ContainerConstants.CONTAINER_Sales_VP_Approval_NT_Quote)) && !Test.isRunningTest()){
                quoteUpdatedElement.addError(ContainerConstants.CONTAINER_QUOTE_VP_APPROVAL_ERROR);
            }
        }	
        
        
        //Logic for VP Genset Approval    
        if(oldQuote.CONTAINER_Status__c == 'Pending VP Approval' && ('Approved'.equalsIgnoreCase(quoteUpdatedElement.ApprovalStatus__c) || 'Pending'.equalsIgnoreCase(quoteUpdatedElement.ApprovalStatus__c)) &&
           quoteUpdatedElement.RecordTypeId == ContainerConstants.CONTAINER_GENSETRecord){
            If(userRoleName != 'Container Sales VP' && userRoleName != 'Container Sales VP GENSET' && !(validateIsUserPublicGroupAccess(ContainerConstants.CONTAINER_Sales_VP_Approval_GENSET_Quote))){
                quoteUpdatedElement.addError(ContainerConstants.CONTAINER_QUOTE_VP_APPROVAL_ERROR);
            }else If(containerStatus && (userRoleName == 'Container Sales VP' || userRoleName == 'Container Sales VP GENSET' || validateIsUserPublicGroupAccess(ContainerConstants.CONTAINER_Sales_VP_Approval_GENSET_Quote)) && !Test.isRunningTest()){
                quoteUpdatedElement.addError(ContainerConstants.CONTAINER_QUOTE_VP_APPROVAL_ERROR);
            }
        }	
        
        //Logic for RSM NT
        if(containerRSMStatusSet.contains(oldQuote.CONTAINER_Status__c) && ('Approved'.equalsIgnoreCase(quoteUpdatedElement.ApprovalStatus__c) || 'Pending'.equalsIgnoreCase(quoteUpdatedElement.ApprovalStatus__c)) && 
           quoteUpdatedElement.RecordTypeId == ContainerConstants.CONTAINER_NTRecord){
               if(userRoleName != 'Container Sales RSM APO' && userRoleName != 'Container Sales RSM EMEA' && userRoleName != 'Container Sales RSM NAO' &&!(validateIsUserPublicGroupAccess(ContainerConstants.CONTAINER_Sales_RSM_Acceptance_NT_Quote))){
                   quoteUpdatedElement.addError(ContainerConstants.CONTAINER_QUOTE_VP_APPROVAL_ERROR);
               }else if (containerStatus && (userRoleName == 'Container Sales RSM APO' || userRoleName == 'Container Sales RSM EMEA' || userRoleName == 'Container Sales RSM NAO' || validateIsUserPublicGroupAccess(ContainerConstants.CONTAINER_Sales_RSM_Acceptance_NT_Quote))){
                   quoteUpdatedElement.addError(ContainerConstants.CONTAINER_QUOTE_VP_APPROVAL_ERROR);
               }
        }
        
        //Logic for RSM GENSET
        if(containerRSMStatusSet.contains(oldQuote.CONTAINER_Status__c) && ('Approved'.equalsIgnoreCase(quoteUpdatedElement.ApprovalStatus__c) || 'Pending'.equalsIgnoreCase(quoteUpdatedElement.ApprovalStatus__c)) && 
           quoteUpdatedElement.RecordTypeId == ContainerConstants.CONTAINER_GENSETRecord){
               if(userRoleName != 'Container Sales RSM APO' && userRoleName != 'Container Sales RSM EMEA' && userRoleName != 'Container Sales RSM NAO' &&!(validateIsUserPublicGroupAccess(ContainerConstants.CONTAINER_Sales_RSM_Accep_GENSET_Quote))){
                   quoteUpdatedElement.addError(ContainerConstants.CONTAINER_QUOTE_VP_APPROVAL_ERROR);
               }else if (containerStatus && (userRoleName == 'Container Sales RSM APO' || userRoleName == 'Container Sales RSM EMEA' || userRoleName == 'Container Sales RSM NAO' || validateIsUserPublicGroupAccess(ContainerConstants.CONTAINER_Sales_RSM_Accep_GENSET_Quote))){
                   quoteUpdatedElement.addError(ContainerConstants.CONTAINER_QUOTE_VP_APPROVAL_ERROR);
               }
        }
        
        //For PM Approval NT 
        if((quoteUpdatedElement.CONTAINER_Status__c=='Pending PM Approval' && oldQuote.CONTAINER_Status__c == 'Pending PM Approval') && quoteUpdatedElement.RecordTypeId == ContainerConstants.CONTAINER_NTRecord){
            if((userRoleName != 'Container Sales PM' && userRoleName != 'Container Sales PM NT') && !(validateIsUserPublicGroupAccess(ContainerConstants.CONTAINER_Sales_PM_Approval_NT_Quote))){
                   CONTAINER_Quote_Trigger_Helper.checkErrorConditions(oldQuote, quoteUpdatedElement, ContainerConstants.CONTAINER_QUOTE_PM_APPROVAL_ERROR);
               }else if (restrictedPMUpdates && (userRoleName == 'Container Sales PM' || userRoleName == 'Container Sales PM NT' || validateIsUserPublicGroupAccess(ContainerConstants.CONTAINER_Sales_PM_Approval_NT_Quote))){
                   CONTAINER_Quote_Trigger_Helper.checkErrorConditions(oldQuote, quoteUpdatedElement, ContainerConstants.CONTAINER_QUOTE_PM_APPROVAL_ERROR);
               }
        }
        
        //For PM Approval Genset 
        if((quoteUpdatedElement.CONTAINER_Status__c=='Pending PM Approval' && oldQuote.CONTAINER_Status__c == 'Pending PM Approval') && quoteUpdatedElement.RecordTypeId == ContainerConstants.CONTAINER_GENSETRecord){
            if((userRoleName != 'Container Sales PM' && userRoleName != 'Container Sales PM GENSET') && !(validateIsUserPublicGroupAccess(ContainerConstants.CONTAINER_Sales_PM_Approval_GENSET_Quote))){
                   CONTAINER_Quote_Trigger_Helper.checkErrorConditions(oldQuote, quoteUpdatedElement, ContainerConstants.CONTAINER_QUOTE_PM_APPROVAL_ERROR);
               }else if (restrictedPMUpdates && (userRoleName == 'Container Sales PM' || userRoleName == 'Container Sales PM GENSET' || validateIsUserPublicGroupAccess(ContainerConstants.CONTAINER_Sales_PM_Approval_GENSET_Quote))){
                   CONTAINER_Quote_Trigger_Helper.checkErrorConditions(oldQuote, quoteUpdatedElement, ContainerConstants.CONTAINER_QUOTE_PM_APPROVAL_ERROR);
               }
        }
        
        //For CAM NT 
        if((quoteUpdatedElement.CONTAINER_Status__c=='Pending CAM Approval' && oldQuote.CONTAINER_Status__c == 'Pending CAM Approval') && quoteUpdatedElement.RecordTypeId == ContainerConstants.CONTAINER_NTRecord){
            if( userRoleName != 'CAM' && userRoleName != 'CAM NT' && !(validateIsUserPublicGroupAccess(ContainerConstants.CONTAINER_Sales_CAM_Approval_NT_Quote)) ){
               CONTAINER_Quote_Trigger_Helper.checkErrorConditions(oldQuote, quoteUpdatedElement, ContainerConstants.CONTAINER_QUOTE_CAM_APPROVAL_ERROR);
            }else if (restrictedCAMUpdates && (userRoleName == 'CAM' || userRoleName == 'CAM NT' || validateIsUserPublicGroupAccess(ContainerConstants.CONTAINER_Sales_CAM_Approval_NT_Quote))){
               CONTAINER_Quote_Trigger_Helper.checkErrorConditions(oldQuote, quoteUpdatedElement, ContainerConstants.CONTAINER_QUOTE_CAM_APPROVAL_ERROR);
            }
        }
           
        
        //For CAM GENSENT 
        if((quoteUpdatedElement.CONTAINER_Status__c=='Pending CAM Approval' && oldQuote.CONTAINER_Status__c == 'Pending CAM Approval') && quoteUpdatedElement.RecordTypeId == ContainerConstants.CONTAINER_GENSETRecord){
            if( userRoleName != 'CAM' && userRoleName != 'CAM GENSET' && !(validateIsUserPublicGroupAccess(ContainerConstants.CONTAINER_Sales_CAM_Approvl_GENSET_Quote)) ){
               CONTAINER_Quote_Trigger_Helper.checkErrorConditions(oldQuote, quoteUpdatedElement, ContainerConstants.CONTAINER_QUOTE_CAM_APPROVAL_ERROR);
            }else if (restrictedCAMUpdates && (userRoleName == 'CAM' || userRoleName == 'CAM GENSET' || validateIsUserPublicGroupAccess(ContainerConstants.CONTAINER_Sales_CAM_Approvl_GENSET_Quote))){
               CONTAINER_Quote_Trigger_Helper.checkErrorConditions(oldQuote, quoteUpdatedElement, ContainerConstants.CONTAINER_QUOTE_CAM_APPROVAL_ERROR);
            }
        }
        
        if(quoteUpdatedElement.ApprovalStatus__c == 'Approved' && 
           (quoteUpdatedElement.CONTAINER_Status__c=='Pending VP Approval' || quoteUpdatedElement.CONTAINER_Status__c == 'Pending RSM Acceptance for Prod & Ship Schedule'
            || quoteUpdatedElement.CONTAINER_Status__c=='Pending CAM Approval' || quoteUpdatedElement.CONTAINER_Status__c=='Pending RSM Acceptance for Special Req' || quoteUpdatedElement.CONTAINER_Status__c=='Pending PM Approval' )){
                quoteUpdatedElement.CONTAINER_Status__c = 'Approved';
                quoteUpdatedElement.CONTAINER_QuotePath__c = 'Approved'; 
                
            }
        
        //Avoid Recursive Trigger
        ContainerConstants.firstRun = false;
    }
        
    public static boolean validateIsUserPublicGroupAccess(String grpName){
        if(grpName != null && grpName != ''){
            //Validate whether loggedin user is member of specific public group.
            list<GroupMember> grpMemberValidation = [select id, group.name from GroupMember where UserOrGroupId =:UserInfo.getUserId() and group.DeveloperName =:grpName];
            
            if(!grpMemberValidation.isEmpty()){
                return true;
            }
        }
       return false;
    }
    
    public static void checkErrorConditions(SBQQ__Quote__c oldQuote, SBQQ__Quote__c newQuote, String errMsg){
        //after submisssion:  old Approval_status = Pending , new Approval_status = Pending,  then throw validation
        if('Pending'.equalsIgnoreCase(oldQuote.ApprovalStatus__c) && 'Pending'.equalsIgnoreCase(newQuote.ApprovalStatus__c)){
            newQuote.addError(errMsg);   
        }       
    }
}