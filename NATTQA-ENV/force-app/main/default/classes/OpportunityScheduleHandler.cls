public class OpportunityScheduleHandler {

    public static void syncPickDatesToSchedule(List<Opportunity_Scheduled_Pick_Date__c> pickDates) {
        if (pickDates == null || pickDates.isEmpty()) return;

        Set<Id> oppIds = new Set<Id>();
        for (Opportunity_Scheduled_Pick_Date__c pd : pickDates) {
            if (pd.Opportunity__c != null) {
                oppIds.add(pd.Opportunity__c);
            }
        }
        if (oppIds.isEmpty()) return;

        List<OpportunityLineItem> baseUnitOLIs = [
            SELECT Id, OpportunityId, Product2.NATT_Is_Base_Unit__c, TotalPrice, Quantity,Product2.CanUseQuantitySchedule,Product2.CanUseRevenueSchedule,Product2.Name
            FROM OpportunityLineItem
            WHERE OpportunityId IN :oppIds AND Product2.NATT_Is_Base_Unit__c = true and Opportunity.RecordType.Name IN  ( 'Units', 'CTBR Units', 'MX Units', 'CONTAINER Opportunity') ];
        

        
        List<OpportunityLineItemSchedule> schedulesToInsert = new List<OpportunityLineItemSchedule>();

        for (Opportunity_Scheduled_Pick_Date__c pd : pickDates) {
            if (pd.Scheduled_Date__c == null || pd.Scheduled_Quantity__c == null) continue;
            Boolean errorAdded = false;
            for (OpportunityLineItem oli : baseUnitOLIs) {
                if (oli.OpportunityId != pd.Opportunity__c) continue;
                
                if (!oli.Product2.CanUseQuantitySchedule ||!oli.Product2.CanUseRevenueSchedule) {

                    if (!errorAdded) {
                      pd.addError('Scheduling cannot proceed for product "' + oli.Product2.Name + '" because it does not support both Quantity and Revenue scheduling. Please update the product configuration to enable these options.');
                        errorAdded = true;
                    }
                    continue;
                }

                   OpportunityLineItemSchedule sched = new OpportunityLineItemSchedule();
                    sched = new OpportunityLineItemSchedule();
                    sched.OpportunityLineItemId = oli.Id;
                    sched.Type = 'Both';
                    sched.Revenue = oli.TotalPrice;
                    sched.Quantity = oli.Quantity;
                    sched.ScheduleDate = pd.Scheduled_Date__c;
                    schedulesToInsert.add(sched);
            }
        }

        
        if (!schedulesToInsert.isEmpty()) {
            upsert schedulesToInsert;
        }
         
    }
}