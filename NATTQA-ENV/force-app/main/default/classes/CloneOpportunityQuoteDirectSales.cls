/**
* @File Name        : CloneOpportunityQuoteDirectSales.cls
* @Description      : Clones an Opportunity, its CPQ Quote (SBQQ__Quote__c), and Quote Lines (SBQQ__QuoteLine__c).
* @Author           : Vamsi Mogidi
* @Last Modified On : Sept 15, 2025
* @Version          : 2.0 (Refactored with Utility Methods)
**/
public without sharing class CloneOpportunityQuoteDirectSales {

    // ------------------ WRAPPER ------------------
    public class CloneResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id newOpportunityId;
        @AuraEnabled public Id newQuoteId;
        @AuraEnabled public Integer newQLICount;

        public CloneResult(Boolean success, String message) {
            this.success = success;
            this.message = message;
            this.newQLICount = 0;
        }
    }

    // ------------------ ENTRY POINT ------------------
    @AuraEnabled
    public static CloneResult cloneOpportunityWithQuote(Id opportunityId) {
        if (opportunityId == null) {
            return new CloneResult(false, 'No Opportunity Id provided.');
        }

        Savepoint sp = Database.setSavepoint();
        CloneResult result = new CloneResult(true, null);

        try {
            // 1) Get source opportunity
            Opportunity srcOpp = fetchOpportunity(opportunityId);

            // 2) Clone opportunity
            Opportunity newOpp = cloneOpportunity(srcOpp);
            insert newOpp;
            result.newOpportunityId = newOpp.Id;

            // 3) Get related quote
            SBQQ__Quote__c srcQuote = fetchQuote(srcOpp.Id);
            if (srcQuote == null) {
                result.message = 'Opportunity cloned. No CPQ Quote found to clone.';
                return result;
            }

            // 4) Clone quote
            SBQQ__Quote__c newQuote = cloneQuote(srcQuote, newOpp);
            insert newQuote;
            result.newQuoteId = newQuote.Id;

            // 5) Get related quote lines
            List<SBQQ__QuoteLine__c> srcLines = fetchQuoteLines(srcQuote.Id);
            if (srcLines.isEmpty()) {
                result.message = 'Opportunity and Quote cloned. No Quote Lines found.';
                return result;
            }

            // 6) Clone quote lines
            Integer qliCount = cloneQuoteLines(srcLines, newQuote.Id);
            result.newQLICount = qliCount;

            // 7) Mark new quote as primary and update opp name
            finalizeQuoteAndOpportunity(newQuote.Id, newOpp.Id, srcOpp.Name);

            // 8) Send notification
            sendCloneNotification(newOpp);

            result.message = 'Cloned successfully: Opportunity, CPQ Quote, and ' + qliCount + ' Quote Line(s).';
            return result;

        } catch (Exception ex) {
            Database.rollback(sp);
            return new CloneResult(false, 'Clone failed: ' + ex.getMessage()+ 'Line Number' + ex.getLineNumber());
        }
    }

    // ------------------ UTILITY METHODS ------------------

    // Fetch source opportunity
    private static Opportunity fetchOpportunity(Id oppId) {
        return [
            SELECT Id, Name, AccountId, StageName, CloseDate, OwnerId, RecordTypeId, CurrencyIsoCode, Pricebook2Id,NATT_Customer_Category__c,
            NATT_Billing_Address__c,NATT_Opportunity_Range__c,NATT_Product_Family__c,NATT_Region__c,NATT_Shipping_Address__c,NATT_Status__c,
            NATT_Unit__c,NATT_Stock__c,NATT_Telematics_eSolutions__c,Total_Deal_Probability__c,NATT_End_Customer__c,
            NATT_Opportunity_Percentage__c,Description,CreatedById
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];
    }

    // Clone opportunity
    private static Opportunity cloneOpportunity(Opportunity srcOpp) {
            Opportunity newOpp = srcOpp.clone(false, false, false, false);
            newOpp.Name         = srcOpp.Name + ' - Clone';
            newOpp.StageName    = 'Quoting';
            newOpp.CloseDate    = System.today().addDays(120);
            newOpp.Opportunity_Source__c = srcOpp.Id;
            newOpp.Pricebook2Id=srcOpp.Pricebook2Id;
            newOpp.OwnerId=UserInfo.getUserId();
           
            if (Schema.sObjectType.Opportunity.fields.CurrencyIsoCode.isAccessible() && srcOpp.CurrencyIsoCode != null) {
                newOpp.CurrencyIsoCode = srcOpp.CurrencyIsoCode;
            }
        return newOpp;
            }

    // Fetch quote
    private static SBQQ__Quote__c fetchQuote(Id oppId) {
        List<SBQQ__Quote__c> quotes = [
            SELECT Id, SBQQ__Opportunity2__c, SBQQ__PricebookId__c, CurrencyIsoCode, SBQQ__Primary__c,RecordTypeId,SBQQ__Account__c,SBQQ__BillingCity__c,SBQQ__BillingCountry__c,SBQQ__BillingName__c,SBQQ__BillingPostalCode__c,SBQQ__BillingState__c,SBQQ__BillingStreet__c,SBQQ__ConsumptionRateOverride__c,SBQQ__ContractingMethod__c,SBQQ__DefaultTemplate__c,
            SBQQ__EndDate__c,SBQQ__ExpirationDate__c,SBQQ__OrderByQuoteLineGroup__c,SBQQ__OrderBy__c,SBQQ__OrderGroupID__c,SBQQ__PrimaryContact__c,SBQQ__QuoteLanguage__c,SBQQ__QuoteTemplateId__c,SBQQ__SalesRep__c,SBQQ__ShippingCity__c,SBQQ__ShippingCountry__c,SBQQ__ShippingName__c,SBQQ__ShippingPostalCode__c,SBQQ__ShippingState__c,SBQQ__ShippingStreet__c,
            SBQQ__Source__c,EditLinesFieldSetName__c,HeaderFieldSetName__c,NATT_Billing_Address_Account_Id__c,NATT_Competitor_Model_Options__c,NATT_Customer_Type__c,NATT_Dealer_Credit__c,NATT_End_Customer_Company__c,NATT_Quote_Line_View__c,NATT_Quote_Record_Type_Developer_Name__c,NATT_Product_Family__c,NATT_Competitive_Unit_Model__c,NATT_Market_Segment2__c,
            NATT_Shipment_Method__c,NATT_Shipment_Terms__c,NATT_Shipping_Address_Account_Id__c,NATT_Special_Terms__c,NATT_Standard_Features__c,NATT_Unit__c,QUO_Quote_Short_Description__c,CaseSafeId__c,Competitor_Model_Price__c,NATT_Account_Name__c,NATT_BluEdge_Core__c,NATT_BluEdge_Elite__c,NATT_BluEdge_Enhance__c,Mark_For_Location_Country__c,
            NATT_BluEdge_Quote_Type__c,NATT_BluEdge_Terms__c,NATT_Dealer_Copy__c,NATT_Dealer_Name__c,NATT_Dealer_Sales_Rep_Email__c,NATT_Dealer_Sales_Rep_Phone__c,NATT_Discounted_BluEdge__c,NATT_End_Customer__c,NATT_EnforceUnitKeyValidation__c,NATT_Important_Note__c,Quote_Guide__c,NATT_BluEdge_Document_Logo__c,Mark_For_Location_State__c,NATT_Active_Unit__c,
            NATT_Billing_Address__c,NATT_Shipping_Address__c,CreatedById,Source_Opportunity__c
            FROM SBQQ__Quote__c
            WHERE SBQQ__Opportunity2__c = :oppId
            LIMIT 1
        ];
        return (quotes.isEmpty() ? null : quotes[0]);
    }

    // Clone quote
    private static SBQQ__Quote__c cloneQuote(SBQQ__Quote__c srcQuote, Opportunity newOpp) {
            SBQQ__Quote__c newQuote = srcQuote.clone(false, false, false, false);
             newQuote.SBQQ__Opportunity2__c = newOpp.Id;
             newQuote.SBQQ__PricebookId__c  = newOpp.Pricebook2Id;
             newQuote.SBQQ__Status__c = 'Draft';
             newQuote.SBQQ__Type__c = 'Quote';
            newQuote.SBQQ__Source__c       = srcQuote.Id;
            newQuote.SBQQ__Account__c=srcQuote.SBQQ__Account__c;
            newQuote.Source_Opportunity__c=newOpp.Opportunity_Source__c;
             newQuote.NATT_Quote_Record_Type_Developer_Name__c = 'NATT_Direct_Sales';
             newQuote.OwnerId=UserInfo.getUserId();
            
            if (Schema.sObjectType.SBQQ__Quote__c.fields.CurrencyIsoCode.isAccessible() && srcQuote.CurrencyIsoCode != null) {
                newQuote.CurrencyIsoCode = srcQuote.CurrencyIsoCode;
            }
            newQuote.SBQQ__Primary__c = false;
            system.debug('Quote Details '+ newQuote);
            System.debug('Opportuntiy Details '+ newQuote.SBQQ__Opportunity2__c );
            System.debug('pricebook Details '+ newQuote.SBQQ__PricebookId__c);
            System.debug('currency  Details '+ newQuote.CurrencyIsoCode);
           // System.debug('Account Details '+ newQuote.CurrencyIsoCode);


        return newQuote;
            }

    // Fetch quote lines
    private static List<SBQQ__QuoteLine__c> fetchQuoteLines(Id quoteId) {
        return [
            SELECT Id, SBQQ__Quote__c, SBQQ__NetPrice__c, SBQQ__ListPrice__c, SBQQ__Discount__c,SBQQ__ConfigurationRequired__c,SBQQ__CostEditable__c,SBQQ__Description__c,SBQQ__DynamicOptionId__c,SBQQ__EffectiveEndDate__c,SBQQ__EffectiveStartDate__c,SBQQ__Existing__c,SBQQ__Hidden__c,
                SBQQ__NonDiscountable__c,SBQQ__NonPartnerDiscountable__c,SBQQ__Number__c,SBQQ__OptionLevel__c,SBQQ__OptionType__c,SBQQ__Optional__c,SBQQ__PriceEditable__c,SBQQ__PricebookEntryId__c,SBQQ__PricingMethodEditable__c,SBQQ__PricingMethod__c,SBQQ__ProductCode__c,SBQQ__ProductFamily__c,SBQQ__ProductName__c,SBQQ__ProductOption__c,
                SBQQ__ProductSubscriptionType__c,SBQQ__Product__c,SBQQ__ProrateMultiplier__c,SBQQ__Quantity__c,SBQQ__Renewal__c,SBQQ__SubscriptionBase__c,SBQQ__SubscriptionScope__c,SBQQ__SubscriptionType__c,SBQQ__UpliftAmount__c,SBQQ__Uplift__c,NATT_APU__c,NATT_Antifreeze_Price_per_gal__c,NATT_Auto_Start_Stop_Operation__c,
                NATT_Battery_Price__c,NATT_Battery_Replacement_Interval__c,NATT_BluEdge_Price_Type__c,NATT_Bundle_Name__c,NATT_Bus__c,NATT_EMCC__c,NATT_Engine_Hours_per_Period__c,NATT_Is_Base_Unit__c,NATT_P_N__c,NATT_Quote_Template_Section__c,NATT_Trailer__c,NATT_Truck__c,NATT_Unit__c,NATT_Use_in_Template__c,NATT_BluEdge_Price_Rollup__c,
                NATT_BluEdge_Terms__c,NATT_BluEdge_Top_Level_Bundle__c,NATT_Bundle_Key__c,NATT_Bundle_P_N_Key__c,NATT_Core__c,NATT_Exclude_From_Discount_Calculations__c,NATT_Feature_Category__c,NATT_Grouped_By_Line_Number__c,NATT_Part_Information__c,NATT_Quote_Record_Type_ID__c,NATT_Quote_Recordtype_Dev_Name__c,NATT_Quote_Status__c,NATT_Quote_Type__c,
                NATT_RequiredByProductName__c,NATT_Serial_Number__c,NATT_Unit_Tavant_Id2__c,NATT_Unit_Tavant_Id__c,SBQQ__RequiredBy__c,SBQQ__RequiredBy__r.SBQQ__Number__c
                FROM SBQQ__QuoteLine__c
            WHERE SBQQ__Quote__c = :quoteId
        ];
    }
           
    // Clone quote lines
    public static Integer cloneQuoteLines(List<SBQQ__QuoteLine__c> srcLines, Id newQuoteId) {
        List<SBQQ__QuoteLine__c> parentQuoteLines = new List<SBQQ__QuoteLine__c>();
        Map<Decimal, Decimal> childToParentLines = new Map<Decimal, Decimal>();
            List<SBQQ__QuoteLine__c> newLines = new List<SBQQ__QuoteLine__c>();

            for (SBQQ__QuoteLine__c line : srcLines) {
                SBQQ__QuoteLine__c nl = line.clone(false, false, false, false);
                nl.SBQQ__Quote__c = newQuoteId;
                nl.SBQQ__Quantity__c = 1;

            if (nl.SBQQ__RequiredBy__c == null) {
                parentQuoteLines.add(nl);
            } else {
                childToParentLines.put(nl.SBQQ__Number__c, nl.SBQQ__RequiredBy__r.SBQQ__Number__c);
            }
            newLines.add(nl);
        }

        if (!parentQuoteLines.isEmpty()) {
            System.debug('ParentQuoteLines'+parentQuoteLines);
            insert parentQuoteLines;
        }

        Map<Decimal, Id> parentMap = new Map<Decimal, Id>();
        for (SBQQ__QuoteLine__c pl : [
            SELECT Id, SBQQ__Number__c FROM SBQQ__QuoteLine__c WHERE Id IN :parentQuoteLines
        ]) {
            parentMap.put(pl.SBQQ__Number__c, pl.Id);
        }

        List<SBQQ__QuoteLine__c> updateList = new List<SBQQ__QuoteLine__c>();
        for (SBQQ__QuoteLine__c ql : newLines) {
            if (ql.SBQQ__RequiredBy__c != null) {
                ql.SBQQ__RequiredBy__c = parentMap.get(childToParentLines.get(ql.SBQQ__Number__c));
                updateList.add(ql);
            }
        }
        if (!updateList.isEmpty()) {
            insert updateList;
        }

        return updateList.size();
    }

    // Finalize quote and opp
    private static void finalizeQuoteAndOpportunity(Id quoteId, Id oppId, String srcOppName) {
        SBQQ__Quote__c newQuote = [SELECT Id, Name, SBQQ__Primary__c FROM SBQQ__Quote__c WHERE Id = :quoteId LIMIT 1];
        newQuote.SBQQ__Primary__c = true;
        update newQuote;

        Opportunity opp = [SELECT Id, Name FROM Opportunity WHERE Id = :oppId LIMIT 1];
        opp.Name = srcOppName + '-' + newQuote.Name + '-Clone';
            update opp;
    }

    // Send notification
    private static void sendCloneNotification(Opportunity newOpp) {
            Set<String> recipients = new Set<String>();
        Group notifyGroup = [SELECT Id FROM Group WHERE DeveloperName = 'Dirext_Sales_Clone_Notification' LIMIT 1];
            recipients.add(notifyGroup.Id);

        sendCustomNotification(
            recipients, 
            newOpp.Id, 
            'Clone Successful', 
            'Your Opportunity/Quote has been cloned successfully. New Opportunity: ' + newOpp.Name
        );
    }
   
    // ------------------ REUSABLE: Notification ------------------
   public static void sendCustomNotification(Set<String> recipientIds, Id targetRecordId, String title, String body) {
    try {
        Set<String> userIds = new Set<String>();

        for (String recId : recipientIds) {
            String prefix = recId.left(3);
            if (prefix == '005') {
                userIds.add(recId);
            } else if (prefix == '00G') {
                    for (GroupMember gm : [SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :recId]) {
                    if (gm.UserOrGroupId.getSObjectType() == User.sObjectType) {
                            userIds.add((String) gm.UserOrGroupId);
                    }
                }
            }
        }

            if (userIds.isEmpty()) return;

        CustomNotificationType notifType = [
                SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Clone_Notification' LIMIT 1
        ];

        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        notification.setTitle(title);
        notification.setBody(body);
        notification.setNotificationTypeId(notifType.Id);
        notification.setTargetId(targetRecordId);
        notification.send(userIds);
    } catch (Exception e) {
        System.debug('❌ Error sending custom notification: ' + e.getMessage());
    }
    }

    // ------------------ REUSABLE: Quote Approval Check ------------------
    @AuraEnabled(cacheable=true)
    public static Boolean isQuoteApproved(Id opportunityId, Datetime clientTime) {
    if (opportunityId == null) return false;

    List<Opportunity> OppList = [
        SELECT Id, StageName
        FROM Opportunity
        WHERE Id = :opportunityId and Opportunity_Source__c = null
        LIMIT 1
    ];
        Set<String> allowedOppStatuses = new Set<String>(Label.DirectSalesAllowedOppStages.split(','));

    if (OppList.isEmpty()) return false;

        Boolean isTrue = (allowedOppStatuses != null && !allowedOppStatuses.isEmpty() && allowedOppStatuses.contains(OppList[0].StageName));
        return istrue;
    }
}