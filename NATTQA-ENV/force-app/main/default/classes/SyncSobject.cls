/************************
* @name SyncSobject
* @description Common class to sync Account, contact and NATT_Extended_Warranty__c
* @date 9 August 2021
* @author DS
* @changes
************************/

public class SyncSobject {
    
    //DS to sync NAAT and TAVANT org
    public static void syncSobject(List<SObject> trgNew){
        
        //profile check condition
        /*String usrProfileName = [SELECT Profile.Name 
FROM User 
WHERE id = :Userinfo.getUserId()].Profile.Name;

String usrProfileId = Userinfo.getProfileId();
String labelProfileId = System.Label.System_Administrator_Id;
System.debug('Userinfo.getUserId' + usrProfileId);
if(usrProfileId == labelProfileId){*/
        
        Set<ID> sObjID = new Set<ID>();
        String sObjName = '';
        String relatedRecords = '';
        String recordID = trgNew[0].ID;
        
        sObjName = getObjectAPIName(recordID);
        
        for(SObject sobj : trgNew){
            
            if(sObjName == 'Account'){
                Account acc = (Account) sobj;
                if((acc.NATT_Record_Type_Developer_Name__c == 'Dealer' || acc.NATT_Record_Type_Developer_Name__c == 'MX_Dealer')&& acc.NATT_Status__c == 'Active' && acc.NATT_Warranty_Status__c == 'Active'){
                    relatedRecords = 'Contact';
                    sObjID.add(acc.id);
                }
            }
            // Commented out in ContactTriggerHandlerNATT - Ramkumar Murugesan on 20th Jan 2023
            else if(sObjName == 'Contact'){
                Contact con = (Contact) sobj;
                if(con.NATT_Record_Type_Developer_Name__c  == 'NATT_Dealer' || con.NATT_Record_Type_Developer_Name__c == 'MX_Dealer'){
                    relatedRecords = 'Account';
                    sObjID.add(con.id);
                }
            }
            else if(sObjName == 'NATT_Extended_Warranty__c'){
                NATT_Extended_Warranty__c obj = (NATT_Extended_Warranty__c) sobj;
                sObjID.add(obj.ID);
            }
        }
        
        if(sObjID.size() >0) {
            // Commented out - failing for NATT deployment - - Ramkumar Murugesan on 20th Jan 2023
            Id networkId = getConnectionID();
            
            if(networkId != null){
                
                List<PartnerNetworkRecordConnection> recordShares = new List<PartnerNetworkRecordConnection>();
                
                for(id sObjIDVar : sObjID ){
                    recordShares.add(new PartnerNetworkRecordConnection(
                        ConnectionId = networkId,
                        LocalRecordId = sObjIDVar,
                        RelatedRecords = relatedRecords
                    ));
                }
                
                if(!test.isRunningTest()){
                insert recordShares;
            }
                
        }
        }
        //}
    }
    
    private static string getObjectAPIName(ID recordId){
        String objectAPIName = '';
        objectAPIName = recordId.getSObjectType().getDescribe().getName();
        return objectAPIName;
    }
    // Commented out - failing for NATT deployment - Ramkumar Murugesan on 20th Jan 2023
    private static ID getConnectionID(){
        Id networkId ;
        String connName ='Carrier Transicold Europe'; // Connection Name 
        
        List<PartnerNetworkConnection> conns = [SELECT ID, connectionStatus 
                                                FROM 
                                                PartnerNetworkConnection 
                                                WHERE ConnectionName = :connName
                                                AND connectionStatus = 'Accepted'];
        
        if(conns.size()>0) {
            networkId = conns[0].id;
            return networkId;
        }
        return '';
    }
}