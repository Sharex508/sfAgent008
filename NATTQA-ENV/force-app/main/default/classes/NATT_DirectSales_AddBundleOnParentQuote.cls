public class NATT_DirectSales_AddBundleOnParentQuote {
    public class Request {
        @InvocableVariable(required=true)
        public Id QuoteId; // EXPECTED: Quote Id (kept your name)
        @InvocableVariable(required=true)
        public Integer timesToAdd;
         @InvocableVariable(required=true)
        public Id SourceQuoteId;
    }

    public class Result {
        @InvocableVariable public Boolean IsSuccess;
        @InvocableVariable public String  Message; 
    }

    @InvocableMethod( 
        label='Clone One Bundle N Times'
        description='Given a Quote Id, finds up to N bundle parents on that Quote and clones those parents + children onto the source quote.'
    )
    public static List<Result> cloneOneBundleNtimes(List<Request> requests) {
        List<Result> outs = new List<Result>();
        if (requests == null || requests.isEmpty()) return outs;

        for (Request req : requests) {
            Result res = new Result();
            res.IsSuccess = false; // default

            try { 
               
                Id destQuoteId = req.SourceQuoteId;
                
                if (destQuoteId == null) {
                    res.Message = 'Destination Quote (SBQQ__Source__c) is null; cannot clone.';
                    outs.add(res);
                    continue;
                }
                if (req.timesToAdd == null || req.timesToAdd <= 0) {
                    res.Message = 'timesToAdd must be > 0.';
                    outs.add(res);
                    continue;
                }

                Id quoteId = req.QuoteId;
                Integer noOfBundles = req.timesToAdd;

                // 1) Pick up to N parent bundle lines on this Quote
                Map<Id, SBQQ__QuoteLine__c> baseParents = new Map<Id, SBQQ__QuoteLine__c>([
                    SELECT Id, SBQQ__Quote__c, SBQQ__Quote__r.SBQQ__Source__c
                    FROM SBQQ__QuoteLine__c
                    WHERE SBQQ__Quote__c = :quoteId
                      AND SBQQ__RequiredBy__c = null AND NATT_Is_Base_Unit__c = true
                    ORDER BY CreatedDate DESC
                    LIMIT :noOfBundles
                ]);
                
                if (baseParents.isEmpty()) {
                    res.Message = 'No bundle parents found on Quote ' + quoteId + '.'; outs.add(res); continue;
                }

                // 2) Gather parents + their children as template lines
                List<SBQQ__QuoteLine__c> templateLines = [
                    SELECT Id, SBQQ__Quote__c, SBQQ__NetPrice__c, SBQQ__ListPrice__c, SBQQ__Discount__c,
                           SBQQ__ConfigurationRequired__c, SBQQ__CostEditable__c, SBQQ__Description__c,
                           SBQQ__DynamicOptionId__c, SBQQ__EffectiveEndDate__c, SBQQ__EffectiveStartDate__c,
                           SBQQ__Existing__c, SBQQ__Hidden__c, SBQQ__NonDiscountable__c,
                           SBQQ__NonPartnerDiscountable__c, SBQQ__Number__c, SBQQ__OptionLevel__c,
                           SBQQ__OptionType__c, SBQQ__Optional__c, SBQQ__PriceEditable__c,
                           SBQQ__PricebookEntryId__c, SBQQ__PricingMethodEditable__c, SBQQ__PricingMethod__c,
                           SBQQ__ProductCode__c, SBQQ__ProductFamily__c, SBQQ__ProductName__c,
                           SBQQ__ProductOption__c, SBQQ__ProductSubscriptionType__c, SBQQ__Product__c,
                           SBQQ__ProrateMultiplier__c, SBQQ__Quantity__c, SBQQ__Renewal__c,
                           SBQQ__SubscriptionBase__c, SBQQ__SubscriptionScope__c, SBQQ__SubscriptionType__c,
                           SBQQ__UpliftAmount__c, SBQQ__Uplift__c, NATT_APU__c, NATT_Antifreeze_Price_per_gal__c,
                           NATT_Auto_Start_Stop_Operation__c, NATT_Battery_Price__c,
                           NATT_Battery_Replacement_Interval__c, NATT_BluEdge_Price_Type__c, NATT_Bundle_Name__c,
                           NATT_Bus__c, NATT_EMCC__c, NATT_Engine_Hours_per_Period__c, NATT_Is_Base_Unit__c,
                           NATT_P_N__c, NATT_Quote_Template_Section__c, NATT_Trailer__c, NATT_Truck__c,
                           NATT_Unit__c, NATT_Use_in_Template__c, NATT_BluEdge_Price_Rollup__c,
                           NATT_BluEdge_Terms__c, NATT_BluEdge_Top_Level_Bundle__c, NATT_Bundle_Key__c,
                           NATT_Bundle_P_N_Key__c, NATT_Core__c, NATT_Exclude_From_Discount_Calculations__c,
                           NATT_Feature_Category__c, NATT_Grouped_By_Line_Number__c, NATT_Part_Information__c,
                           NATT_Quote_Record_Type_ID__c, NATT_Quote_Recordtype_Dev_Name__c, NATT_Quote_Status__c,
                           NATT_Quote_Type__c, NATT_RequiredByProductName__c, NATT_Serial_Number__c,
                           NATT_Unit_Tavant_Id2__c, NATT_Unit_Tavant_Id__c, SBQQ__RequiredBy__c,
                           SBQQ__RequiredBy__r.SBQQ__Number__c
                    FROM SBQQ__QuoteLine__c
                    WHERE (Id IN :baseParents.keySet() OR SBQQ__RequiredBy__c IN :baseParents.keySet())
                      AND SBQQ__Quote__c = :quoteId
                ];

                if (templateLines.isEmpty()) {
                    res.Message = 'No template lines (parents/children) found to clone for Quote ' + quoteId + '.'; outs.add(res); continue;
                }

                // 3) Determine destination Quote (using Source on the current Quote)
              

                // 4) Clone using your existing helper
                Integer clonedCount = CloneOpportunityQuoteDirectSales.cloneQuoteLines(templateLines, destQuoteId);

                res.IsSuccess = (clonedCount != null && clonedCount > 0);
                res.Message   = res.IsSuccess
                    ? 'Cloned ' + clonedCount + ' lines (' + baseParents.size() + ') bundles on parent Quote.'
                    : 'No lines were cloned.';
            } catch (Exception e) {
                res.IsSuccess = false; res.Message   = 'Error: ' + e.getMessage();
            }

            outs.add(res);
        }

        return outs;
    }
}