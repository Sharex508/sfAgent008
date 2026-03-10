/********************************************************************************************************
* @author         Deloitte
* @description    An CONTAINER_TriggerHandler class is created for governing the Trigger Handling.
* @date           03/29/2022 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Deloitte               03/29/2022                                   Initial version
*********************************************************************************************************/


public virtual class CONTAINER_TriggerHandler {
    // static map of handlername, times run() was invoked
    private static Map<String, LoopCount> loopCountMap;
    private static Set<String> bypassedHandlers;
    private static Set<String> setMetadataTriggerClass = new Set<String>();
    
    // the current context of the trigger, overridable in tests
    @TestVisible
    private TriggerContext context;
    
    // the current context of the trigger, overridable in tests
    @TestVisible
    private Boolean isTriggerExecuting;
    
    // static initialization
    static {
        loopCountMap = new Map<String, LoopCount>();
        bypassedHandlers = new Set<String>();
        for(CONTAINER_Control_Trigger_And_Validation__mdt eachMD: [SELECT DeveloperName, CONTAINER_Skip_Trigger_Flag__c, CONTAINER_Trigger_Class_Name__c FROM CONTAINER_Control_Trigger_And_Validation__mdt WHERE CONTAINER_Skip_Trigger_Flag__c = TRUE]){
            setMetadataTriggerClass.add(eachMD.CONTAINER_Trigger_Class_Name__c);
        }
        system.debug('setMetadataTriggerClass '+setMetadataTriggerClass);
        
    }
    
    // constructor
    public CONTAINER_TriggerHandler() {
        this.setTriggerContext();
    }
    
    /***************************************
* public instance methods
***************************************/
    
    // main method that will be called during execution
    public void run() {
        
        if(!validateRun()) return;
        
        addToLoopCount();
        
        // dispatch to the correct handler method
        if(this.context == TriggerContext.BEFORE_INSERT) {
            this.beforeInsert();
        } else if(this.context == TriggerContext.BEFORE_UPDATE) {
            this.beforeUpdate();
        } else if(this.context == TriggerContext.BEFORE_DELETE) {
            this.beforeDelete();
        } else if(this.context == TriggerContext.AFTER_INSERT) {
            this.afterInsert();
        } else if(this.context == TriggerContext.AFTER_UPDATE) {
            this.afterUpdate();
        } else if(this.context == TriggerContext.AFTER_DELETE) {
            this.afterDelete();
        } else if(this.context == TriggerContext.AFTER_UNDELETE) {
            this.afterUndelete();
        }
        
    }
    
    public void setMaxLoopCount(Integer max) {
        String handlerName = getHandlerName();
        if(!CONTAINER_TriggerHandler.loopCountMap.containsKey(handlerName)) {
            CONTAINER_TriggerHandler.loopCountMap.put(handlerName, new LoopCount(max));
        } else {
            CONTAINER_TriggerHandler.loopCountMap.get(handlerName).setMax(max);
        }
    }
    
    public void clearMaxLoopCount() {
        this.setMaxLoopCount(-1);
    }
    
    /***************************************
* public static methods
***************************************/
    
    /********************************************************************************************************
* @author        Deloitte
* @date          03/29/2022
* @description   to by pass any Trigger logic of an Object
* @Paramters     Name of the Class to be byPassed

*********************************************************************************************************/ 
    
    public static void bypass(String handlerName) {
        CONTAINER_TriggerHandler.bypassedHandlers.add(handlerName);
    }
    
    /********************************************************************************************************
* @author        Deloitte
* @date          03/29/2022
* @description   to clear bypass of Trigger logic of an Object
* @Paramters     Name of the CLass to be cleared from the bypass rule

*********************************************************************************************************/ 
    public static void clearBypass(String handlerName) {
        CONTAINER_TriggerHandler.bypassedHandlers.remove(handlerName);
    }
    
    /********************************************************************************************************
* @author        Deloitte
* @date          03/29/2022
* @description   To check if a Trigger logic is bypassed
* @Paramters     Class Name

*********************************************************************************************************/ 
    
    public static Boolean isBypassed(String handlerName) {
        return CONTAINER_TriggerHandler.bypassedHandlers.contains(handlerName);
    }
    
    /********************************************************************************************************
* @author        Deloitte
* @date          03/29/2022
* @description   To clear all bypass Trigger logic 
* @Paramters     

*********************************************************************************************************/
    public static void clearAllBypasses() {
        CONTAINER_TriggerHandler.bypassedHandlers.clear();
    }
    
    /***************************************
* private instancemethods
***************************************/
    
    @TestVisible
    private void setTriggerContext() {
        this.setTriggerContext(null, false);
    }
    
    @TestVisible
    private void setTriggerContext(String ctx, Boolean testMode) {
        if(!Trigger.isExecuting && !testMode) {
            this.isTriggerExecuting = false;
            return;
        } else {
            this.isTriggerExecuting = true;
        }
        
        if((Trigger.isExecuting && Trigger.isBefore && Trigger.isInsert) ||
           (ctx != null && ctx == 'before insert')) {
               this.context = TriggerContext.BEFORE_INSERT;
           } else if((Trigger.isExecuting && Trigger.isBefore && Trigger.isUpdate) ||
                     (ctx != null && ctx == 'before update')){
                         this.context = TriggerContext.BEFORE_UPDATE;
                     } else if((Trigger.isExecuting && Trigger.isBefore && Trigger.isDelete) ||
                               (ctx != null && ctx == 'before delete')) {
                                   this.context = TriggerContext.BEFORE_DELETE;
                               } else if((Trigger.isExecuting && Trigger.isAfter && Trigger.isInsert) ||
                                         (ctx != null && ctx == 'after insert')) {
                                             this.context = TriggerContext.AFTER_INSERT;
                                         } else if((Trigger.isExecuting && Trigger.isAfter && Trigger.isUpdate) ||
                                                   (ctx != null && ctx == 'after update')) {
                                                       this.context = TriggerContext.AFTER_UPDATE;
                                                   } else if((Trigger.isExecuting && Trigger.isAfter && Trigger.isDelete) ||
                                                             (ctx != null && ctx == 'after delete')) {
                                                                 this.context = TriggerContext.AFTER_DELETE;
                                                             } else if((Trigger.isExecuting && Trigger.isAfter && Trigger.isUndelete) ||
                                                                       (ctx != null && ctx == 'after undelete')) {
                                                                           this.context = TriggerContext.AFTER_UNDELETE;
                                                                       }
    }
    
    // increment the loop count
    @TestVisible
    private void addToLoopCount() {
        String handlerName = getHandlerName();
        if(CONTAINER_TriggerHandler.loopCountMap.containsKey(handlerName)) {
            Boolean exceeded = CONTAINER_TriggerHandler.loopCountMap.get(handlerName).increment();
            if(exceeded) {
                Integer max = CONTAINER_TriggerHandler.loopCountMap.get(handlerName).max;
                throw new TriggerHandlerException('Maximum loop count of ' + String.valueOf(max) + ' reached in ' + handlerName);
                /* Insert Log Message Utility code to persist the exception*/
            }
        }
    }
    
    /********************************************************************************************************
* @author        Deloitte
* @date          03/29/2022
* @description   to validate or skip the current run of Trigger
* @Paramters     Trigger context Old list

*********************************************************************************************************/ 
    @TestVisible
    private Boolean validateRun() {
        if(!this.isTriggerExecuting || this.context == null) {
            throw new TriggerHandlerException('Trigger handler called outside of Trigger execution');
            /* Insert Log Message Utility code to persist the exception*/
        }
        if(CONTAINER_TriggerHandler.bypassedHandlers.contains(getHandlerName())) {
            return false;
        }
        /*INTRODUCED LOGIC TO BY PASS TRIGGERS IF SKIP TRIGGER IS CHCEKED */
        if(!setMetadataTriggerClass.isEmpty() && setMetadataTriggerClass.contains(getHandlerName())){
            return false;
        }
        return true;
    }
    
    @TestVisible
    private String getHandlerName() {
        return String.valueOf(this).substring(0,String.valueOf(this).indexOf(':'));
    }
    
    /***************************************
* context methods
***************************************/
    
    // context-specific methods for override
    @TestVisible
    protected virtual void beforeInsert(){}
    @TestVisible
    protected virtual void beforeUpdate(){}
    @TestVisible
    protected virtual void beforeDelete(){}
    @TestVisible
    protected virtual void afterInsert(){}
    @TestVisible
    protected virtual void afterUpdate(){}
    @TestVisible
    protected virtual void afterDelete(){}
    @TestVisible
    protected virtual void afterUndelete(){}
    
    /***************************************
* inner classes
***************************************/
    
    // inner class for managing the loop count per handler
    @TestVisible
    private class LoopCount {
        private Integer max;
        private Integer count;
        
        public LoopCount() {
            this.max = 5;
            this.count = 0;
        }
        
        public LoopCount(Integer max) {
            this.max = max;
            this.count = 0;
        }
        
        public Boolean increment() {
            this.count++;
            return this.exceeded();
        }
        
        public Boolean exceeded() {
            if(this.max < 0) return false;
            if(this.count > this.max) {
                return true;
            }
            return false;
        }
        
        public Integer getMax() {
            return this.max;
        }
        
        public Integer getCount() {
            return this.count;
        }
        
        public void setMax(Integer max) {
            this.max = max;
        }
    }
    
    // possible trigger contexts
    @TestVisible
    private enum TriggerContext {
        BEFORE_INSERT, BEFORE_UPDATE, BEFORE_DELETE,
            AFTER_INSERT, AFTER_UPDATE, AFTER_DELETE,
            AFTER_UNDELETE
            }
    
    // exception class
    public class TriggerHandlerException extends Exception {}
}