/********************************************************************************************************
* @author         Deloitte
* @description    This class creates the record for ASO Review Report
* @date           07/27/2022 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Deloitte               07/27/2022                                   Initial version
*********************************************************************************************************/

public without sharing class CONTAINERQuoteSnapshotReview {
    
    public static final list<CONTAINER_Quote_Snapshot__c> SNAPSHOTRECORDLIST = new list<CONTAINER_Quote_Snapshot__c>();
    public static final Map<string, string> QUOTESNAPMAP = new Map<string, string>();
    
    @AuraEnabled
    public static string deleteQuoteSnapshotRecords(){
        
       string url;
        if(!Test.isRunningTest()){
            //query the report Id of ASO Review Report
            Id reportId = [select id from report where DeveloperName ='ASO_Review_Report_7OX'].Id;
            url = '/lightning/r/Report/'+reportId+'/view';
        }
        
        //Return ASO review Report Url 
        return url;
    }   
    
    
    //Methos called from Batch Apex 
    public static void Processbatch(List<SBQQ__Quote__c> quoteList){
        //Delete all old snapshot record
        processOldSnapshotDeletion(quoteList);  
        
        //Process Quote and Quoteline data
        preDefinedQuotelineData();
        processAllRecordstoMap(quoteList);
        
        //insert all record to quote snapshot
        insertQuoteSnapshotRecords(SNAPSHOTRECORDLIST);
    } 
    
   
    //Method to get all NT quote and related quote lines.
    public static void processAllRecordstoMap(List<SBQQ__Quote__c> quoteList){
        Map<Id, SBQQ__QuoteLine__c> quoteLineMap = new Map<Id, SBQQ__QuoteLine__c>();
        Map<Id, SBQQ__Quote__c> quoteMap = new Map<Id, SBQQ__Quote__c>();
        
        //Get the values from Quote object
        Map<Id, SBQQ__Quote__c> quoteRecord = new Map<Id, SBQQ__Quote__c>([SELECT Id, CONTAINER_ASO_ID__c, CONTAINER_Job__c, CONTAINER_Qty__c, CONTAINER_Model_Number__c, CONTAINER_PID__c,
                                                                           CONTAINER_PO_Number__c,CONTAINER_Order__c, SBQQ__Account__c, CONTAINER_WON_Date__c, CONTAINER_Total_Weight_Unit_Options_Kg__c,
                                                                           CONTAINER_Build_Form__c, CONTAINER_ASO_Revision_Comments__c,Factory_Rework_CONTAINER__c, Container_Factory_Rework_Comments__c,
                                                                           CONTAINER_Commissioning_Work_Order_Info__c, Container_Commissioning_WO_Comments__c, CONTAINER_Datacordor_Config_Option__c   
                                                                           FROM SBQQ__Quote__c where id=:quoteList]);  
        
        Map<Id, SBQQ__QuoteLine__c> quoteLineMapRec = new Map<Id, SBQQ__QuoteLine__c>([SELECT Id, SBQQ__Quote__c, SBQQ__ProductName__c, CONTAINER_Feature__c, CONTAINER_Warranty_Description__c, 
                                                                                       NATT_P_N__c  FROM SBQQ__QuoteLine__c where SBQQ__Quote__c =:quoteRecord.keySet()]);
        
        
        for(Id quoteIterate : quoteRecord.keySet()){
            for(Id quotelineIterate : quoteLineMapRec.keySet()){
                if(quoteIterate == quoteLineMapRec.get(quotelineIterate).SBQQ__Quote__c){
                    quoteLineMap.put(quotelineIterate, quoteLineMapRec.get(quotelineIterate));
                    quoteLineMapRec.remove(quotelineIterate);
                }
            }
            quoteMap.put(quoteIterate, quoteRecord.get(quoteIterate));
            createDataForQuoteLineFeatures(quoteMap, quoteLineMap);
            quoteMap.clear();
            quoteLineMap.clear();
        } 
    }
    
    //Update the Map with redefined values.
    public static void preDefinedQuotelineData(){
        //Map to hold values of Quote snapshot field api names and features name
        QUOTESNAPMAP.put('AIR EXCHANGE','CONTAINER_Air_Exchange__c');
        QUOTESNAPMAP.put('VENT POSITION SENSOR','CONTAINER_Vent_Positioning_Sensor__c');
        QUOTESNAPMAP.put('UPPER AIR EXCHANGE LABELS','CONTAINER_UPPER_AIR_EXCHANGE_LABELS__c');
        QUOTESNAPMAP.put('MODIFIED ATMOSPHERE','CONTAINER_MODIFIED_ATMOSPHERE_CA__c');
        QUOTESNAPMAP.put('DEHUMIDIFICATION','CONTAINER_DEHUMIDIFICATION__c');
        QUOTESNAPMAP.put('NITROGEN PORT','CONTAINER_NITROGEN_PORT__c');
        QUOTESNAPMAP.put('LEAKAGE','CONTAINER_LEAKAGE__c');
        QUOTESNAPMAP.put('CONTROLLER','CONTAINER_CONTROLLER__c');
        //QUOTESNAPMAP.put('DATACORDER CONFIGURATION','CONTAINER_DATACORDER_CONFIGURATION__c');
        QUOTESNAPMAP.put('QUEST','CONTAINER_QUEST__c');
        QUOTESNAPMAP.put('REFRIG TEMP SENSOR','CONTAINER_REFRIG_TEMP_SENSOR__c');
        QUOTESNAPMAP.put('PRESSURE GAUGES','CONTAINER_COMPRESSOR_PRESSURE_GUAGES__c');
        QUOTESNAPMAP.put('INTERROGATOR','CONTAINER_INTERROGATOR__c');
        QUOTESNAPMAP.put('RM RECEPTACLE','CONTAINER_RM_RECEPTACLE__c');
        QUOTESNAPMAP.put('RMU','CONTAINER_RMU__c');
        QUOTESNAPMAP.put('USDA','CONTAINER_USDA__c');
        QUOTESNAPMAP.put('EBS','CONTAINER_EBS__c');
        QUOTESNAPMAP.put('THERMO PORT','CONTAINER_THERMO_PORT__c');
        QUOTESNAPMAP.put('ARCTIC OPTION','CONTAINER_ARCTIC_OPTION__c');
        QUOTESNAPMAP.put('BATTERY','CONTAINER_BATTERY__c');
        QUOTESNAPMAP.put('CABLE RESTRAINT','CONTAINER_CABLE_RESTRAINT__c');
        QUOTESNAPMAP.put('CABLE TYPE','CONTAINER_CABLE_TYPE__c');
        QUOTESNAPMAP.put('DUAL VOLTAGE','CONTAINER_DUAL_VOLTAGE__c');
        QUOTESNAPMAP.put('PLUG 230V','CONTAINER_PLUG_230V__c');
        QUOTESNAPMAP.put('PLUG 460V','CONTAINER_PLUG_460V__c');
        QUOTESNAPMAP.put('BOX VACUUM RELIEF VALVE','CONTAINER_BOX_VACUUM_RELIEF_VALVE__c');
        QUOTESNAPMAP.put('BACK PANEL','CONTAINER_BACK_PANEL__c');
        QUOTESNAPMAP.put('BULKHEAD PENETRATION', 'CONTAINER_BULKHEAD_PENETRATION__c');
        QUOTESNAPMAP.put('CERTIFICATION','CONTAINER_CERTIFICATION__c');
        QUOTESNAPMAP.put('CONTROL BOX DOOR WITH REMOVABLE HINGE PIN','CONTAINER_CONTROL_BOX_REMOVABLE_HINGE__c');
        QUOTESNAPMAP.put('CUSTOMER LOGOS & DECALS','CONTAINER_CUSTOMER_LOGOS_DECALS__c');
        QUOTESNAPMAP.put('HANDLES','CONTAINER_HANDLES__c');
        QUOTESNAPMAP.put('LABELS','CONTAINER_LABELS__c');
        QUOTESNAPMAP.put('VOLTAGE SHIELDS','CONTAINER_VOLTAGE_SHIELDS__c');
        QUOTESNAPMAP.put('SPECIAL MOUNTING','CONTAINER_SPECIAL_MOUNTING__c');
        QUOTESNAPMAP.put('FASTENERS','CONTAINER_FASTENERS__c');
        QUOTESNAPMAP.put('RAIN GUTTERS','CONTAINER_RAIN_GUTTERS__c');
        QUOTESNAPMAP.put('BOX LOCKING TAB','CONTAINER_BOX_LOCKING_TAB__c');
        QUOTESNAPMAP.put('DUAL TEMP','CONTAINER_DUAL_TEMP__c');
        QUOTESNAPMAP.put('UPFLOW','CONTAINER_UPFLOW__c');
        QUOTESNAPMAP.put('FUELWISE','CONTAINER_FUELWISE__c');
        QUOTESNAPMAP.put('PLASTIC SHIPPING COVER', 'CONTAINER_PLASTIC_SHIPPING_COVER__c');
        QUOTESNAPMAP.put('REFRIG CHARGE (LBS)','CONTAINER_REFRIG_CHARGE_LBS__c');
        QUOTESNAPMAP.put('CONDENSER','CONTAINER_CONDENSER__c');
        QUOTESNAPMAP.put('CAP 0','CONTAINER_CAP_0__c');
        QUOTESNAPMAP.put('CAP 35','CONTAINER_CAP_35__c');
        QUOTESNAPMAP.put('PROGRAM OPTIONS','CONTAINER_PROGRAM_OPTIONS__c');
        QUOTESNAPMAP.put('EVAP MOTOR','CONTAINER_EVAP_MOTOR__c');
        QUOTESNAPMAP.put('COND MOTOR', 'CONTAINER_COND_MOTOR__c');
        QUOTESNAPMAP.put('Compressor', 'CONTAINER_COMPRESSOR__c');
        QUOTESNAPMAP.put('ANTI-TAMPER REFRIGERANT SEALS', 'CONTAINER_ANTI_TAMPER_REFRIGERANT_SEALS__c');
        QUOTESNAPMAP.put('TRIPWISE', 'CONTAINER_TRIPWISE__c');
        QUOTESNAPMAP.put('RETURN AIR SENSOR WIRE LENGTH', 'CONTAINER_RETURN_AIR_SENSOR_WIRE_LENGTH__c');
        QUOTESNAPMAP.put('RMM AND HARNESS', 'CONTAINER_RMM_and_Harness__c');
        QUOTESNAPMAP.put('RMU FOR ML5', 'CONTAINER_RMU_for_ML5__c');
        QUOTESNAPMAP.put('REFRIGERANT', 'CONTAINER_Refrigerant__c');
        QUOTESNAPMAP.put('CE CERTIFICATION MARKING', 'CONTAINER_CE_Certification_Marking__c');
    }
    
    //Validate the quoteline features value with Snapshot object fields. 
    public static void createDataForQuoteLineFeatures(Map<Id, SBQQ__Quote__c> quoteRecord, Map<Id, SBQQ__QuoteLine__c> quoteLineMap){
        Map<string, string> featureMap = new Map<string, string>();
        if(!quoteLineMap.isEmpty()){
            for(String featureMapData : quoteLineMap.KeySet()){
                if(quoteLineMap.get(featureMapData).CONTAINER_Feature__c != 'Compressor' || 
                   (quoteLineMap.get(featureMapData).CONTAINER_Feature__c == 'Compressor' && quoteLineMap.get(featureMapData).CONTAINER_Feature__c.isAllUpperCase()) ){
                       featureMap.put(quoteLineMap.get(featureMapData).CONTAINER_Feature__c, quoteLineMap.get(featureMapData).SBQQ__ProductName__c);
                   }
            }
        }
        
        //pass Quote and line item map to Create Quote Snapshot method
        mapQuotetoQuoteSnanshot(quoteRecord, quoteLineMap, featureMap);
    }
    
    //Method to process new Quote Snapshot records and stored it into list.
    public static void mapQuotetoQuoteSnanshot(Map<ID, SBQQ__Quote__c> quoteRecord, Map<Id, SBQQ__QuoteLine__c> quoteLineRecord, Map<string, string> featureMap){
        //Initialize new quote snapshot req
        CONTAINER_Quote_Snapshot__c newQuoteSnapshotRec = new CONTAINER_Quote_Snapshot__c();
        
        //Bulkify the Insert operations
        for(Id quoteId : quoteRecord.KeySet()){
            //Insert new Quote Snapshot record.
            newQuoteSnapshotRec.put(Schema.CONTAINER_Quote_Snapshot__c.CONTAINER_Quote__c, quoteId);
            newQuoteSnapshotRec.put(Schema.CONTAINER_Quote_Snapshot__c.CONTAINER_ASO_Number__c, quoteRecord.get(quoteId).CONTAINER_ASO_ID__c);
            newQuoteSnapshotRec.put(Schema.CONTAINER_Quote_Snapshot__c.CONTAINER_Sales_Order_Date__c, String.valueOf(quoteRecord.get(quoteId).CONTAINER_WON_Date__c));
            newQuoteSnapshotRec.put(Schema.CONTAINER_Quote_Snapshot__c.CONTAINER_Job_Number__c, quoteRecord.get(quoteId).CONTAINER_Job__c); 
            newQuoteSnapshotRec.put(Schema.CONTAINER_Quote_Snapshot__c.CONTAINER_Customer__c, quoteRecord.get(quoteId).SBQQ__Account__c);
            newQuoteSnapshotRec.put(Schema.CONTAINER_Quote_Snapshot__c.CONTAINER_Qty__c, String.valueOf(quoteRecord.get(quoteId).CONTAINER_Qty__c));
            newQuoteSnapshotRec.put(Schema.CONTAINER_Quote_Snapshot__c.CONTAINER_Model__c, quoteRecord.get(quoteId).CONTAINER_Model_Number__c);
            newQuoteSnapshotRec.put(Schema.CONTAINER_Quote_Snapshot__c.CONTAINER_PID_No__c, quoteRecord.get(quoteId).CONTAINER_PID__c);
            newQuoteSnapshotRec.put(Schema.CONTAINER_Quote_Snapshot__c.CONTAINER_ASO_Issue_Dt__c, String.valueOf(quoteRecord.get(quoteId).CONTAINER_Order__c));
            newQuoteSnapshotRec.put(Schema.CONTAINER_Quote_Snapshot__c.CONTAINER_Total_Unit_Option_Weight__c, String.valueOf(quoteRecord.get(quoteId).CONTAINER_Total_Weight_Unit_Options_Kg__c));
            newQuoteSnapshotRec.put(Schema.CONTAINER_Quote_Snapshot__c.CONTAINER_BUILT_FROM__c, quoteRecord.get(quoteId).CONTAINER_Build_Form__c);
            newQuoteSnapshotRec.put(Schema.CONTAINER_Quote_Snapshot__c.CONTAINER_ASO_Comments__c, quoteRecord.get(quoteId).CONTAINER_ASO_Revision_Comments__c);
            newQuoteSnapshotRec.put(Schema.CONTAINER_Quote_Snapshot__c.CONTAINER_DATACORDER_CONFIGURATION__c, quoteRecord.get(quoteId).CONTAINER_Datacordor_Config_Option__c);
            
            
            if(quoteRecord.get(quoteId).Factory_Rework_CONTAINER__c != null){
                string factoryRework = quoteRecord.get(quoteId).Factory_Rework_CONTAINER__c + '\r\n';
                if(quoteRecord.get(quoteId).Container_Factory_Rework_Comments__c != null){
                    factoryRework= factoryRework + quoteRecord.get(quoteId).Container_Factory_Rework_Comments__c;
                }
                newQuoteSnapshotRec.put(Schema.CONTAINER_Quote_Snapshot__c.CONTAINER_Factory_Rework_Up__c, factoryRework);
            }else if(quoteRecord.get(quoteId).Container_Factory_Rework_Comments__c != null){
                newQuoteSnapshotRec.put(Schema.CONTAINER_Quote_Snapshot__c.CONTAINER_Factory_Rework_Up__c, quoteRecord.get(quoteId).Container_Factory_Rework_Comments__c);
            }
            
            if(quoteRecord.get(quoteId).CONTAINER_Commissioning_Work_Order_Info__c  != null){
                string quoteSnap = quoteRecord.get(quoteId).CONTAINER_Commissioning_Work_Order_Info__c  + '\r\n';
                if(quoteRecord.get(quoteId).Container_Commissioning_WO_Comments__c != null){
                    quoteSnap = quoteSnap + quoteRecord.get(quoteId).Container_Commissioning_WO_Comments__c;
                }
                newQuoteSnapshotRec.put(Schema.CONTAINER_Quote_Snapshot__c.CONTAINER_Commissioning_Work_Order_Up__c, quoteSnap);
            }else if(quoteRecord.get(quoteId).Container_Commissioning_WO_Comments__c != null){
                newQuoteSnapshotRec.put(Schema.CONTAINER_Quote_Snapshot__c.CONTAINER_Commissioning_Work_Order_Up__c, quoteRecord.get(quoteId).Container_Commissioning_WO_Comments__c);
            }
        }
        
        //UNit,Motor,Compressor, Special option process
        mapQuotetLinetoUnitMotorCompressor(newQuoteSnapshotRec, quoteLineRecord, featureMap);
        
    }
    
    
    public static void mapQuotetLinetoUnitMotorCompressor(CONTAINER_Quote_Snapshot__c newQuoteSnapshotRec, Map<Id, SBQQ__QuoteLine__c> quoteLineRecord, Map<string, string> featureMap){
        //Code to set the values for Unit/Motor/Compressor/Special option
        String specialOptionDet;
        
        for(Id warrantyDetails : quoteLineRecord.KeySet()){
            if(quoteLineRecord.get(warrantyDetails).CONTAINER_Feature__c == 'Unit' && quoteLineRecord.get(warrantyDetails).NATT_P_N__c != null){
                newQuoteSnapshotRec.put(Schema.CONTAINER_Quote_Snapshot__c.CONTAINER_Warranty_Unit__c, quoteLineRecord.get(warrantyDetails).NATT_P_N__c + 'YR') ;
            }else if(quoteLineRecord.get(warrantyDetails).CONTAINER_Feature__c == 'Motor' && quoteLineRecord.get(warrantyDetails).NATT_P_N__c != null){
                newQuoteSnapshotRec.put(Schema.CONTAINER_Quote_Snapshot__c.CONTAINER_Warranty_Motor__c, quoteLineRecord.get(warrantyDetails).NATT_P_N__c + 'YR');
            }else if(quoteLineRecord.get(warrantyDetails).CONTAINER_Feature__c == 'Compressor' && !quoteLineRecord.get(warrantyDetails).CONTAINER_Feature__c.isAllUpperCase() && quoteLineRecord.get(warrantyDetails).NATT_P_N__c != null){
                newQuoteSnapshotRec.put(Schema.CONTAINER_Quote_Snapshot__c.CONTAINER_Warranty_Compressor__c, quoteLineRecord.get(warrantyDetails).NATT_P_N__c + 'YR');
            }else if(quoteLineRecord.get(warrantyDetails).SBQQ__ProductName__c == 'Special Product Requirements' && quoteLineRecord.get(warrantyDetails).CONTAINER_Warranty_Description__c != null && quoteLineRecord.get(warrantyDetails).CONTAINER_Warranty_Description__c != ''){
                specialOptionDet = String.IsNotEmpty(specialOptionDet) ? (specialOptionDet + quoteLineRecord.get(warrantyDetails).CONTAINER_Warranty_Description__c + '\r\n') : (quoteLineRecord.get(warrantyDetails).CONTAINER_Warranty_Description__c + '\r\n');
                    }
        }
        
        //Assign the Special option value after all iteration.
        if(String.IsNotEmpty(specialOptionDet)){
            newQuoteSnapshotRec.put(Schema.CONTAINER_Quote_Snapshot__c.CONTAINER_Special_Option__c, specialOptionDet); 
        } 
        
        //Process all other quote line data
        mapQuotetLinesdata(newQuoteSnapshotRec, quoteLineRecord, featureMap);
    }
    
    
    
    //Method to process new Quote Snapshot records and stored it into list.
    public static void mapQuotetLinesdata(CONTAINER_Quote_Snapshot__c newQuoteSnapshotRec, Map<Id, SBQQ__QuoteLine__c> quoteLineRecord, Map<string, string> featureMap){
        //Process to set the values of Quote line features
        for(String featureValue : featureMap.KeySet()){
            for(String quoteSnapNames : QUOTESNAPMAP.KeySet()){
                if(featureValue == quoteSnapNames && featureMap.get(featureValue) != null){
                    string fieldApiName = QUOTESNAPMAP.get(quoteSnapNames);
                    fieldApiName = String.escapeSingleQuotes(fieldApiName);
                    newQuoteSnapshotRec.put(fieldApiName, featureMap.get(featureValue));  
                    
                }
            }
        }
        
        //Adding the record into the list
        SNAPSHOTRECORDLIST.add(newQuoteSnapshotRec);
    }
    
    
    //Insert the list of record to Quote Snapshot object.
    public static void insertQuoteSnapshotRecords(list<CONTAINER_Quote_Snapshot__c> snapShortRecList){
        try{
            database.insert(snapShortRecList, false);
        }
        catch(Exception e) {
            System.debug('Exception hit on Insertion:' + e);
        }
    }
    
    //delete old snapshot records
     public static void processOldSnapshotDeletion(List<SBQQ__Quote__c> quoteList){
        list<CONTAINER_Quote_Snapshot__c> snapShotList= [select id from CONTAINER_Quote_Snapshot__c where CONTAINER_Quote__c=:quoteList];
        
        try{
            if(!snapShotList.isEmpty()){
                database.delete(snapShotList, false);
            }
        }
        catch(Exception e) {
            System.debug('Exception hit on Deletions:' + e);
        }
    } 
}