/*
@name: ExtendedWarrantyTrg
@description: To sync NATT_Extended_Warranty__c from NATT to TAVANT
@date: July 29th 2021
@author: DS
@changes:
*/

Trigger ExtendedWarrantyTrg on NATT_Extended_Warranty__c (after insert, after update) {

    if(Trigger.isAfter){
        if(Trigger.isInsert || Trigger.isUpdate){
            SyncSobject.syncSobject(Trigger.new); //commom class to sync objects
        }
    }
}