public virtual class TriggerHandlerVirtual {
    private Schema.SObjectType soType {private get; private set;}
    
    public TriggerHandlerVirtual() {
        
    }

    public TriggerHandlerVirtual(Schema.SObjectType soType){
        this.soType=soType;
    }
    /**
     * Dispatches logic 
     * This method must be called from a Trigger.
     */
    public virtual void execute() {
        if (Trigger.isBefore) {
            if (Trigger.isInsert ) {
                this.handleBeforeInsert(Trigger.new);
            } else if (Trigger.isUpdate ) {
                this.handleBeforeUpdate(Trigger.oldMap, Trigger.newMap);
            } else if (Trigger.isDelete ) {
                this.handleBeforeDelete(Trigger.oldMap);
            }
        } else if (Trigger.isAfter) {
            if (Trigger.isInsert) {
                this.handleAfterInsert(Trigger.newMap);
            } else if (Trigger.isUpdate) {
                this.handleAfterUpdate(Trigger.oldMap, Trigger.newMap);
            } else if (Trigger.isDelete) {
                this.handleAfterDelete(Trigger.oldMap);
            } else if (Trigger.isUndelete) {
                this.handleAfterUndelete(Trigger.newMap);
            }
        }
    }

	// The following methods can be override by trigger handlers
    protected virtual void handleBeforeInsert(List<SObject> newRecordsList) {
    }
    protected virtual void handleBeforeUpdate(Map<Id, SObject> oldRecordsMap, Map<Id, SObject> newRecordsMap) {
    }
    protected virtual void handleBeforeDelete(Map<Id, SObject> oldRecordsMap) {
    }
    protected virtual void handleAfterInsert(Map<Id, SObject> newRecordsMap) {
    }
    protected virtual void handleAfterUpdate(Map<Id, SObject> oldRecordsMap, Map<Id, SObject> newRecordsMap) {
    }
    protected virtual void handleAfterDelete(Map<Id, SObject> oldRecordsMap) {
    }
    protected virtual void handleAfterUndelete(Map<Id, SObject> newRecordsMap) {
    }

}