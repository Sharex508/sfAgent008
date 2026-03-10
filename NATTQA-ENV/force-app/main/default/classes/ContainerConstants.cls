/**************************************************************************************
 * This Class is used to hold all constant values used for Container CPQ Implementation
****************************************************************************************/
public class ContainerConstants {
    
   public static final String  APPROVED_QUOTE_ERROR_MSG = 'The Quote is already Approved.Please Recall and Resubmit to make changes';
   public static final String  SUBMITTED_QUOTE_ERROR_MSG = 'The Quote is already submitted for approval.Please Recall and Resubmit to make changes'; 
   public static final String  SUBMITTED_STATUS = 'Pending';
   public static final String  APPROVED_STATUS = 'Approved'; 
   public static final String  Model_Number_Blank = 'Product Model Can Not Be Blank';
   public static final String  Contract_Price = 'Contract Price Can Not Be Blank';
   public static final String  Payment_terms_Field_Blank = 'Payment terms Can Not Be Blank';
   public static final String  Quantity_Not_Equal_To_RequestedShipDate_Quantity = 'The Total of Requested ship dates records quantity is not equal to the Total Quote Qty, kindly add requested ship date records equal to total quote qty'; 
   public static final String  Method_of_shipment_field_blank = 'Method of shipment Can Not Be Blank';
   public static final String  Freight_Terms_Field_Blank = 'Freight Terms Can Not Be Blank';
   public static final String  Requested_Ship_Dates_Null_Records = 'Requested ship dates Can Not Be Null';
   public static final String  CONTAINER_Quote_ASO_Template= 'CONTAINER Quote ASO Template';
   public static final String  APO = 'APO';
   public static final String  NAO = 'NAO';
   public static final String  EMEA = 'EMEA'; 
   public static final String  CONTAINER_Quote_ASO_GENSET_APO = 'CONTAINER Quote ASO GENSET APO';
   public static final String  CONTAINER_Quote_ASO_GENSET_NAO = 'CONTAINER Quote ASO GENSET NAO';
   public static final String  CONTAINER_Quote_ASO_GENSET_EMEA = 'CONTAINER Quote ASO GENSET EMEA';
   public static final String  CONTAINER_Quote_ASO_NT_APO = 'CONTAINER Quote ASO NT APO';
   public static final String  CONTAINER_Quote_ASO_NT_NAO = 'CONTAINER Quote ASO NT NAO';
   public static final String  CONTAINER_Quote_ASO_NT_EMEA = 'CONTAINER Quote ASO NT EMEA';
   public static final String  CONTAINER_Quote_ASO_ID_ASO_REV_Blank_Error_Msg = 'Both ASO ID and ASO REV are already blank.';
   public static final String  CONTAINER_NT_Quote = 'Container NT Quote';
   public static final String  CONTAINER_GENSET_Quote = 'Container GENSET Quote';
   public static final String  CONTAINER_QUOTE_VP_APPROVAL_ERROR = 'Quote is Pending for Approval and locked, Kindly Recall the approval to make changes.';
   public static final String  CONTAINER_QUOTE_PM_APPROVAL_ERROR = 'As Quote is Pending for PM Approval and locked, Kindly Recall the Approval to make changes.';
   public static final String  CONTAINER_QUOTE_CAM_APPROVAL_ERROR = 'As Quote is Pending for CAM Approval, Kindly Recall the Approval to make changes.';
   public static final String  CONTAINER_Sales_VP_Approval_NT_Quote = 'CONTAINER_Sales_VP_Approval_NT_Quote';
   public static final String  CONTAINER_Sales_VP_Approval_GENSET_Quote = 'CONTAINER_Sales_VP_Approval_GENSET_Quote';
   public static final String  CONTAINER_Sales_RSM_Acceptance_NT_Quote = 'CONTAINER_Sales_RSM_Acceptance_NT_Quote';
   public static final String	CONTAINER_Sales_RSM_Accep_GENSET_Quote = 'CONTAINER_Sales_RSM_Accep_GENSET_Quote';		
   public static final String	CONTAINER_Sales_PM_Approval_NT_Quote = 'CONTAINER_Sales_PM_Approval_NT_Quote';		
   public static final String	CONTAINER_Sales_PM_Approval_GENSET_Quote = 'CONTAINER_Sales_PM_Approval_GENSET_Quote';		
   public static final String	CONTAINER_Sales_CAM_Approval_NT_Quote = 'CONTAINER_Sales_CAM_Approval_NT_Quote';
   public static final String	CONTAINER_Sales_CAM_Approvl_GENSET_Quote = 'CONTAINER_Sales_CAM_Approvl_GENSET_Quote';
   public static final String   CONTAINER_NTRecord = Schema.getGlobalDescribe().get('SBQQ__Quote__c').getDescribe().getRecordTypeInfosByName().get('Container NT Quote').getRecordTypeId();
   public static final String   CONTAINER_GENSETRecord = Schema.getGlobalDescribe().get('SBQQ__Quote__c').getDescribe().getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
   public static boolean firstRun = true; 			

   
   
}