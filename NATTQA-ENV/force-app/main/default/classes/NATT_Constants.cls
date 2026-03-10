public with sharing class NATT_Constants {
    
    /* QUOTE CONSTANTS */
    public static final String QUOTE_DRAFT = 'Draft';
    public static final String QUOTE_PENDING_APPROVAL = 'Pending Approval';
    public static final List<String> QUOTE_STATUS_IN_PROGRESS = getQuoteStatusValues();
    public static final String QUOTE_NATT_UNIT_RT = 'NATT_Units_Quote';

    /* ORDER CONSTANTS */    
    public static final List<String> ORDER_STATUS_IN_PROGRESS = getOrderStatusValues();    
    public static final String ORDER_NATT_UNIT_RT = 'NATT_Units_Order';
    public static final String ORDER_STATUS_COMPLETED = 'Complete';
    public static final String ORDER_STATUS_CANCELLED = 'Cancelled';

    public static final List<String> ORDER_STATUS_COMPLETE_OR_CANCELLED = new List<String>{
        ORDER_STATUS_COMPLETED,
        ORDER_STATUS_CANCELLED
    };

    /* CASE CONSTANTS */
    public static final List<String> CASE_STATUS_IN_PROGRESS = getCaseStatusValues();

    /* ACCOUNT CONSTANTS */
    public static final String ACCOUNT_ACTIVE = 'Active';

    /* KNOWLEDGE CONSTANTS*/
    public static final Map<String, String> KNOWLEDGE_CATEGORIES_BY_LABEL_VIEW = new Map<String, String>{
        'General Bulletin' => 'generalBulletins',
        'Parts Bulletin' => 'partsBulletins',
        'Service Bulletin'  => 'serviceBulletins',
        'Training Bulletin' => 'trainingBulletins',
        'Product Manual Updates'  => 'productManualUpdates',
        'eFlash'  => 'eFlash',
        'Dealer News'  => 'dealerNews'
    };

    /* NATT ADDRESS CONTANSTS */
    public static final String NATT_ADDRESS_TYPE_HEADQUARTERS = 'Headquarters';
    public static final String NATT_ADDRESS_TYPE_PHYSICAL = 'Physical';
    public static final String NATT_ADDRESS_TYPE_MAILING = 'Mailing';

    public static final List<String> NATT_ADDRESS_TYPE_TRIGGER = new List<String>{
        NATT_ADDRESS_TYPE_HEADQUARTERS,
        NATT_ADDRESS_TYPE_PHYSICAL,
        NATT_ADDRESS_TYPE_MAILING
    };
        
   /*User Constants*/
   public static final List<String> NATT_USER_PROFILE_LIST = new List<String>{'CGI Administrator','NATT Account Super User','NATT Accounts Read Only','NATT Associate With Tavant Community','NATT Associate Without Tavant Community',
            'NATT Dealer Master User','NATT Field Staff','NATT Full Access Community','NATT Partner Community User','NATT Parts and Service Community','NATT Parts Only Community',
            'NATT Parts Sales','NATT Sales Only Community','NATT Technical Community','NATT Warranty Only Community'};
                
    /* UTILS */
    private static List<String> getCaseStatusValues() {
        List<CaseStatus> ltCaseStatus = [SELECT Id, MasterLabel FROM CaseStatus WHERE IsClosed = false];
        List<String> ltStringValues = new List<String>();
        
        for (CaseStatus cs : ltCaseStatus) {
            ltStringValues.add(cs.MasterLabel);
        }
        
        return ltStringValues;
    }
    
    private static List<String> getOrderStatusValues() {
        List<String> ltStringValues = new List<String>();
        for (Schema.PicklistEntry pe : Order.NATT_Order_Status__c.getDescribe().getPicklistValues()) {
            if (pe.getLabel() != 'Complete' && pe.getLabel() != 'Cancelled') {
                ltStringValues.add(pe.getLabel());
            }
        }

        return ltStringValues;
    }

    private static List<String> getQuoteStatusValues() {
        List<String> ltStringValues = new List<String>();
        for (Schema.PicklistEntry pe : SBQQ__Quote__c.SBQQ__Status__c.getDescribe().getPicklistValues()) {
            if (pe.getLabel() == QUOTE_DRAFT || pe.getLabel() == QUOTE_PENDING_APPROVAL) {
                ltStringValues.add(pe.getLabel());
            }
        }

        return ltStringValues;
    }

}