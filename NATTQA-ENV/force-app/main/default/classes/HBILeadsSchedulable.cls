global class HBILeadsSchedulable implements schedulable {
 global void execute(SchedulableContext sc) {
        Id batchJobId = Database.executeBatch(new HBILeadsBatch(), 200);
    }
}