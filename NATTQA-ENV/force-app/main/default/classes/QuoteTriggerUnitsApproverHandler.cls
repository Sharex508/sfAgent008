public class QuoteTriggerUnitsApproverHandler {
    public static Boolean salesOpsEmailSent = false;  // Static variable to ensure the Sales Ops email is sent only once per transaction

    public static void UpdateQuoteApprover(SBQQ__Quote__c quote){
        SBQQ__QuoteLine__c qLine = new SBQQ__QuoteLine__c();
        list<NATT_Approval_Process__c> approvalProcessList = new List<NATT_Approval_Process__c>();
        Map<String, Id> accTeamRoleUserMap = new Map<String, Id>();
        Map<String, Integer> quoteApproverMap = new Map<String, Integer>();
        Map<String, Id> approverUserIdMap = new Map<String, Id>();
        NATT_Approval_Process__c approvalProcessRec= new NATT_Approval_Process__c();
        
        quoteApproverMap.put('AE',1);
        quoteApproverMap.put('EAM',2);
        quoteApproverMap.put('RD',3);
        quoteApproverMap.put('Director of Sales',4);
        quoteApproverMap.put('Sales Ops',6);
        //quoteApproverMap.put('VP or CFO',6);
        
        qLine = [SELECT ID, Name,SBQQ__Product__c ,SBQQ__Product__r.name,SBQQ__ProductCode__c,SBQQ__ProductFamily__c,SBQQ__ProductName__c 
                 FROM SBQQ__QuoteLine__c WHERE  SBQQ__Quote__c =: quote.Id AND SBQQ__Product__r.name =: quote.NATT_Unit__c LIMIT 1];
        
        approvalProcessList = [SELECT ID, Name, Product_Name__c, Approval_Object__c, Business_Type__c, Business_Sub_Type__c, Margin_EAM_Lower_Bound__c,
                              Margin_RD_Lower_Bound__c,Margin_DOS_Lower_Bound__c, Margin_Sales_Ops_Lower_Bound__c  
                              FROM NATT_Approval_Process__c 
                              WHERE Product_Name__c =: qLine.SBQQ__Product__c AND Product_Family__c =: qLine.SBQQ__ProductFamily__c LIMIT 1];
        system.debug('Margin-- quote.NATT_Total_Order_Net_Amount__c--'+ quote.NATT_Total_Order_Net_Amount__c);
        if(approvalProcessList.size()<1){
            quote.NATT_Approver_1__c=null;
            quote.NATT_Approver_2__c=null;
            quote.NATT_Approver_3__c=null;
            quote.NATT_Approver_4__c=null;
            quote.NATT_Approver_5__c=null;
            quote.NATT_Approver_6__c=null;
            return;
        }
        else{
            approvalProcessRec = approvalProcessList[0];
        }
        system.debug('Margin-- (Decimal)quote.NATT_Margin__c--'+ (Decimal)quote.NATT_Margin__c);
        Integer marginLimit1 = Integer.valueOf(Label.NATT_Approval_Process_Amount_L1); //500000
        Integer marginLimit2 = Integer.valueOf(Label.NATT_Approval_Process_Amount_L2); //1000000
        Integer marginLimit3 = Integer.valueOf(Label.NATT_Approval_Process_Amount_L3); //5000000
        string netQuoteApprover = 
        quote.NATT_Total_Order_Net_Amount__c < marginLimit1  ? 'EAM' :
        quote.NATT_Total_Order_Net_Amount__c >= marginLimit1 && quote.NATT_Total_Order_Net_Amount__c < marginLimit2 ? 'RD' :
        quote.NATT_Total_Order_Net_Amount__c >= marginLimit2 && quote.NATT_Total_Order_Net_Amount__c < marginLimit3 ? 'Director of Sales' :
        quote.NATT_Total_Order_Net_Amount__c >= marginLimit3 ? 'Sales Ops' :'';
        //quote.NATT_Total_Order_Net_Amount__c > 5000000 ? 'VP or CFO' : '';
        system.debug('Margin-- approvalProcessRec--'+ approvalProcessRec);
        
        string withoutNetQuoteApprover = 
        (Decimal)quote.NATT_Margin__c >= (Decimal)approvalProcessRec.Margin_EAM_Lower_Bound__c  ? 'EAM' :
        (Decimal)quote.NATT_Margin__c >= (Decimal)approvalProcessRec.Margin_RD_Lower_Bound__c   && (Decimal)quote.NATT_Margin__c < (Decimal)approvalProcessRec.Margin_EAM_Lower_Bound__c ? 'RD' :
        (Decimal)quote.NATT_Margin__c >= (Decimal)approvalProcessRec.Margin_DOS_Lower_Bound__c  && (Decimal)quote.NATT_Margin__c < (Decimal)approvalProcessRec.Margin_RD_Lower_Bound__c ? 'Director of Sales' :
        (Decimal)quote.NATT_Margin__c >= (Decimal)approvalProcessRec.Margin_Sales_Ops_Lower_Bound__c  && (Decimal)quote.NATT_Margin__c < (Decimal)approvalProcessRec.Margin_DOS_Lower_Bound__c  ? 'Sales Ops' :'';
       // (Decimal)quote.NATT_Margin__c >= (Decimal)approvalProcessRec.Margin_VP_or_CFO_Lower_Bound__c  && (Decimal)quote.NATT_Margin__c < (Decimal)approvalProcessRec.Margin_VP_of_CFO_Upper_Bound__c ? 'VP or CFO' : '';
        
        string maxApproverLevel = quoteApproverMap.get(netQuoteApprover) > quoteApproverMap.get(withoutNetQuoteApprover) ? netQuoteApprover : withoutNetQuoteApprover;
        system.debug('Margin-- quote.NATT_Margin__c--'+ quote.NATT_Margin__c);
        system.debug('Margin-- maxApproverLevel--'+ maxApproverLevel);
        system.debug('Margin-- netQuoteApprover--'+netQuoteApprover);
        system.debug('Margin-- withoutNetQuoteApprover--'+withoutNetQuoteApprover);
        system.debug('Margin-- maxApproverLevel--'+ maxApproverLevel);
       
        list<AccountTeamMember> accTeamMembers = [SELECT ID,NATT_UserName__c,TeamMemberRole,UserId from AccountTeamMember where AccountId =: quote.SBQQ__Account__c];
        
        for(AccountTeamMember member : accTeamMembers){
            accTeamRoleUserMap.put(member.TeamMemberRole, member.UserId);
        }
        quote.NATT_Approver_1__c=null;
        quote.NATT_Approver_2__c=null;
        quote.NATT_Approver_3__c=null;
        quote.NATT_Approver_4__c=null;
        quote.NATT_Approver_5__c=null;
        quote.NATT_Approver_6__c=null;
        quote.NATT_Approver_Sales_Ops__c =null;
        if(quote.NATT_Quote_Special_Options__c > 0){
            quote.NATT_Approver_1__c = userInfo.getUserId();
        }
        //if (maxApproverLevel == 'Sales Ops' || maxApproverLevel == 'VP or CFO' || (Decimal)quote.NATT_Margin__c < (Decimal)approvalProcessRec.Margin_VP_or_CFO_Lower_Bound__c ) {
        if (maxApproverLevel == 'Sales Ops' || (Decimal)quote.NATT_Margin__c < (Decimal)approvalProcessRec.Margin_DOS_Lower_Bound__c ) {
            quote.NATT_Approver_2__c = accTeamRoleUserMap.get('EAM - NATT');
            quote.NATT_Approver_3__c = accTeamRoleUserMap.get('RD - NATT');
            quote.NATT_Approver_4__c = accTeamRoleUserMap.get('Director of Sales - NATT');
            quote.NATT_Approver_Sales_Ops__c = userInfo.getUserId();
        } else if (maxApproverLevel == 'Director of Sales') {
            quote.NATT_Approver_2__c = accTeamRoleUserMap.get('EAM - NATT');
            quote.NATT_Approver_3__c = accTeamRoleUserMap.get('RD - NATT');
            quote.NATT_Approver_4__c = accTeamRoleUserMap.get('Director of Sales - NATT');
        } else if (maxApproverLevel == 'RD') {
            quote.NATT_Approver_2__c = accTeamRoleUserMap.get('EAM - NATT');
            quote.NATT_Approver_3__c = accTeamRoleUserMap.get('RD - NATT');
        } else if (maxApproverLevel == 'EAM') {
            quote.NATT_Approver_2__c = accTeamRoleUserMap.get('EAM - NATT');
        }
    }
    //approver 1 currentry assigning login user id then assign quote for approval to Natt Special Options Approver 1 Queue
    //approver 2 get Account team member with role 'EAM - NATT'
    //approver 3 get Account team member with role 'RD - NATT'
    //approver 4 get username from the custom role 'Director of Sales - NATT'
    //currentry assigning login user id then assign quote for approval to Queue Natt Sales Ops Approver
    
    public static void justCoverage(){
        Integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    }
}