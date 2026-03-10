public without sharing class Container_Quote_ASOID_Release_Handler {
    @InvocableMethod(label='Get ASO Quote Details')
    public static void container_ASOID_Update(List<String> SBQQQuoteId){
        system.debug('Ids----- :'+SBQQQuoteId);
        
        List<SBQQ__Quote__c> quoteList = [SELECT Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c where Id =: SBQQQuoteId WITH SECURITY_ENFORCED];
        system.debug(quoteList);
        
        // Get all metadata revision mapping records
        Map<Integer,String> mapQuoteRevNumbertoName = new Map<Integer,String>();
        for(CONTAINER_Quote_Revision_Mapping__mdt obj : [SELECT Revision_Name__c, Revision_Number__c FROM CONTAINER_Quote_Revision_Mapping__mdt WITH SECURITY_ENFORCED]){
            if(!mapQuoteRevNumbertoName.containsKey(Integer.valueOf(obj.Revision_Number__c))){
                mapQuoteRevNumbertoName.put(Integer.valueOf(obj.Revision_Number__c),obj.Revision_Name__c);
            } 
        }
        
        // fetch current GENSET ASO ID from all GENSET Quote Filter based on record type & ASO_ID__c != null  sort by ASO_ID__c DESC LIMIT 1
        //List<SBQQ__Quote__c> currentGENSETASOId = [select CONTAINER_ASO_ID__c from SBQQ__Quote__c where CONTAINER_ASO_ID__c != '' and RecordType.name = 'Container GENSET Quote'  ORDER BY CONTAINER_ASO_ID__c DESC limit 1] ;
         SBQQ__Quote__c currentGENSETASOId;
        Integer GensetASOId = 0;
        for(SBQQ__Quote__c objGENSET : [SELECT CONTAINER_ASO_ID__c from SBQQ__Quote__c where CONTAINER_ASO_ID__c != '' and RecordType.name = 'Container GENSET Quote' WITH SECURITY_ENFORCED]){
            if(Integer.valueOf(objGENSET.CONTAINER_ASO_ID__c) > GensetASOId){
                GensetASOId = Integer.valueOf(objGENSET.CONTAINER_ASO_ID__c);
                currentGENSETASOId = objGENSET;
            }
        }
        
        // fetch current NT ASO ID from all NT Quote Filter based on record type & ASO_ID__c!= null  sort by ASO_ID__c DESC LIMIT 1
        //List<SBQQ__Quote__c> currentNTASOId = [select CONTAINER_ASO_ID__c from SBQQ__Quote__c where CONTAINER_ASO_ID__c != '' and RecordType.name = 'Container NT Quote'] ;
        SBQQ__Quote__c currentNTASOId;
        Integer NTASOId = 0;
        for(SBQQ__Quote__c objNT : [SELECT CONTAINER_ASO_ID__c from SBQQ__Quote__c where CONTAINER_ASO_ID__c != '' and RecordType.name = 'Container NT Quote' WITH SECURITY_ENFORCED]){
            if(Integer.valueOf(objNT.CONTAINER_ASO_ID__c) > NTASOId){
                NTASOId = Integer.valueOf(objNT.CONTAINER_ASO_ID__c);
                currentNTASOId = objNT;
            }
        }
        
        List<SBQQ__Quote__c> lstQuote = new List<SBQQ__Quote__c>();
        
        if(!quoteList.isEmpty()){
            for(SBQQ__Quote__c quote : quoteList){
                
                // If GENSET Record Type
                if(quote.RecordTypeId ==  Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId()){
                    if(currentGENSETASOId == null){
                        quote.CONTAINER_Genset_Previous_ASO_ID__c = '0001' ;
                        quote.CONTAINER_ASO_ID__c = '0001';
                        quote.CONTAINER_Status__c = 'ASO Released';
                        quote.CONTAINER_QuotePath__c = 'ASO Released';
                        
                    }else if(String.isBlank(quote.CONTAINER_ASO_ID__c) && String.isBlank(quote.CONTAINER_Genset_Previous_ASO_ID__c)){
                        
                        Integer iNext_ASO_Id = Integer.valueOf(currentGENSETASOId.CONTAINER_ASO_ID__c)+1;
                        system.debug('--'+iNext_ASO_Id);
                        if(String.valueOf(iNext_ASO_Id).length() == 3){
                            quote.CONTAINER_Genset_Previous_ASO_ID__c = '0'+String.valueOf(iNext_ASO_Id) ;
                            quote.CONTAINER_ASO_ID__c ='0'+String.valueOf(iNext_ASO_Id);
                        }else if(String.valueOf(iNext_ASO_Id).length() == 2){
                            quote.CONTAINER_Genset_Previous_ASO_ID__c = '00'+String.valueOf(iNext_ASO_Id) ;
                            quote.CONTAINER_ASO_ID__c ='00'+String.valueOf(iNext_ASO_Id);
                        }else if(String.valueOf(iNext_ASO_Id).length() == 1){
                            quote.CONTAINER_Genset_Previous_ASO_ID__c = '000'+String.valueOf(iNext_ASO_Id) ;
                            quote.CONTAINER_ASO_ID__c ='000'+String.valueOf(iNext_ASO_Id);
                        }else{
                            quote.CONTAINER_Genset_Previous_ASO_ID__c = String.valueOf(iNext_ASO_Id) ;
                            quote.CONTAINER_ASO_ID__c = String.valueOf(iNext_ASO_Id);
                        }
                        
                        
                        quote.CONTAINER_Status__c = 'ASO Released';
                        quote.CONTAINER_QuotePath__c = 'ASO Released';
                        
                        system.debug('-------updated record-----------');
                        system.debug('Previous ASO_ID ='+ quote.CONTAINER_Genset_Previous_ASO_ID__c);
                        system.debug('ASO ID ='+quote.CONTAINER_ASO_ID__c);
                        
                    }else if(String.isBlank(quote.CONTAINER_ASO_ID__c) && !String.isBlank(quote.CONTAINER_Genset_Previous_ASO_ID__c)){
                        if(quote.CONTAINER_ASO_ID__c == null && quote.CONTAINER_Genset_Previous_ASO_ID__c != null){
                            quote.CONTAINER_ASO_ID__c = quote.CONTAINER_Genset_Previous_ASO_ID__c;
                            
                            quote.CONTAINER_Status__c = 'ASO Released';
                            quote.CONTAINER_QuotePath__c = 'ASO Released';
                            system.debug('-------updated record-----------');
                            system.debug('Previous ASO_ID ='+ quote.CONTAINER_Genset_Previous_ASO_ID__c);
                            system.debug('ASO ID ='+quote.CONTAINER_ASO_ID__c);
                        }else if(Integer.valueOf(quote.CONTAINER_Genset_Previous_ASO_ID__c) > Integer.valueOf(currentGENSETASOId.CONTAINER_ASO_ID__c)){
                            Integer iNext_ASO_Id = Integer.valueOf(currentGENSETASOId.CONTAINER_ASO_ID__c)+1;
                            system.debug('--'+iNext_ASO_Id);
                            if(String.valueOf(iNext_ASO_Id).length() == 3){
                                quote.CONTAINER_Genset_Previous_ASO_ID__c = '0'+String.valueOf(iNext_ASO_Id) ;
                                quote.CONTAINER_ASO_ID__c ='0'+String.valueOf(iNext_ASO_Id);
                            }else if(String.valueOf(iNext_ASO_Id).length() == 2){
                                quote.CONTAINER_Genset_Previous_ASO_ID__c = '00'+String.valueOf(iNext_ASO_Id) ;
                                quote.CONTAINER_ASO_ID__c ='00'+String.valueOf(iNext_ASO_Id);
                            }else if(String.valueOf(iNext_ASO_Id).length() == 1){
                                quote.CONTAINER_Genset_Previous_ASO_ID__c = '000'+String.valueOf(iNext_ASO_Id) ;
                                quote.CONTAINER_ASO_ID__c ='000'+String.valueOf(iNext_ASO_Id);
                            }else{
                                quote.CONTAINER_Genset_Previous_ASO_ID__c = String.valueOf(iNext_ASO_Id) ;
                                quote.CONTAINER_ASO_ID__c = String.valueOf(iNext_ASO_Id);
                            }  
                            
                            
                            quote.CONTAINER_Status__c = 'ASO Released';
                            quote.CONTAINER_QuotePath__c = 'ASO Released';
                            
                            system.debug('-------updated record-----------');
                            system.debug('Previous ASO_ID ='+ quote.CONTAINER_Genset_Previous_ASO_ID__c);
                            system.debug('ASO ID ='+quote.CONTAINER_ASO_ID__c);
                        }
                        
                        
                    }else If (!String.isBlank(quote.CONTAINER_ASO_ID__c) && String.isBlank(quote.CONTAINER_ASO_Rev__c)){
                        quote.CONTAINER_GENSET_RevNumber__c = 0;
                        quote.CONTAINER_Revision_Date__c = system.today();
                        quote.CONTAINER_ASO_Rev__c = mapQuoteRevNumbertoName.get(Integer.valueOf(quote.CONTAINER_GENSET_RevNumber__c));
                        system.debug('-------updated 1st Revision record-----------');
                        system.debug('GENSET RevNumber ='+quote.CONTAINER_GENSET_RevNumber__c);
                        system.debug('ASO REV = '+ quote.CONTAINER_ASO_Rev__c);
                    }else If (!String.isBlank(quote.CONTAINER_ASO_ID__c) && !String.isBlank(quote.CONTAINER_ASO_Rev__c)){
                        
                        quote.CONTAINER_Revision_Date__c = system.today();
                        quote.CONTAINER_GENSET_RevNumber__c = quote.CONTAINER_GENSET_RevNumber__c +1;
                        quote.CONTAINER_ASO_Rev__c = mapQuoteRevNumbertoName.get(Integer.valueOf(quote.CONTAINER_GENSET_RevNumber__c));
                        system.debug('-------updated Revision record-----------');
                        system.debug('GENSET RevNumber ='+quote.CONTAINER_GENSET_RevNumber__c);
                        system.debug('ASO REV = '+ quote.CONTAINER_ASO_Rev__c);
                    }
                    quote.CONTAINER_IsRevised__c=TRUE;
                    lstQuote.add(quote);
                    
                }else if(quote.RecordTypeId == Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container NT Quote').getRecordTypeId()){
                    // If NT Record Type
                    if(currentNTASOId == null){
                        quote.CONTAINER_NT_Previous_ASO_ID__c = '0001' ;
                        quote.CONTAINER_ASO_ID__c = '0001';
                        quote.CONTAINER_Status__c = 'ASO Released';
                        quote.CONTAINER_QuotePath__c = 'ASO Released';
                        
                    }else if(quote.CONTAINER_ASO_ID__c == null && quote.CONTAINER_NT_Previous_ASO_ID__c == null){
                        Integer iNext_ASO_Id = Integer.valueOf(currentNTASOId.CONTAINER_ASO_ID__c)+1;
                        if(String.valueOf(iNext_ASO_Id).length() == 3){
                            quote.CONTAINER_NT_Previous_ASO_ID__c = '0'+String.valueOf(iNext_ASO_Id) ;
                            quote.CONTAINER_ASO_ID__c ='0'+String.valueOf(iNext_ASO_Id);
                        }else if(String.valueOf(iNext_ASO_Id).length() == 2){
                            quote.CONTAINER_NT_Previous_ASO_ID__c = '00'+String.valueOf(iNext_ASO_Id) ;
                            quote.CONTAINER_ASO_ID__c ='00'+String.valueOf(iNext_ASO_Id);
                        }else if(String.valueOf(iNext_ASO_Id).length() == 1){
                            quote.CONTAINER_NT_Previous_ASO_ID__c = '000'+String.valueOf(iNext_ASO_Id) ;
                            quote.CONTAINER_ASO_ID__c ='000'+String.valueOf(iNext_ASO_Id);
                        }else{
                            quote.CONTAINER_NT_Previous_ASO_ID__c = String.valueOf(iNext_ASO_Id) ;
                            quote.CONTAINER_ASO_ID__c = String.valueOf(iNext_ASO_Id);
                        }
                        
                        quote.CONTAINER_Status__c = 'ASO Released';
                        quote.CONTAINER_QuotePath__c = 'ASO Released';
                        
                        
                        system.debug('-------updated record-----------');
                        system.debug('Previous ASO_ID ='+ quote.CONTAINER_NT_Previous_ASO_ID__c);
                        system.debug('ASO ID ='+quote.CONTAINER_ASO_ID__c);
                        
                    }else if(quote.CONTAINER_ASO_ID__c == null && quote.CONTAINER_NT_Previous_ASO_ID__c != null){
                        if(Integer.valueOf(quote.CONTAINER_NT_Previous_ASO_ID__c) > Integer.valueOf(currentNTASOId.CONTAINER_ASO_ID__c)){
                            quote.CONTAINER_ASO_ID__c = quote.CONTAINER_NT_Previous_ASO_ID__c;
                            quote.CONTAINER_Status__c = 'ASO Released';
                            quote.CONTAINER_QuotePath__c = 'ASO Released';
                            
                            
                            system.debug('-------updated record-----------');
                            system.debug('Previous ASO_ID ='+ quote.CONTAINER_NT_Previous_ASO_ID__c);
                            system.debug('ASO ID ='+quote.CONTAINER_ASO_ID__c); 
                                                         
                        }else { //if(Integer.valueOf(quote.CONTAINER_NT_Previous_ASO_ID__c) < Integer.valueOf(currentNTASOId.CONTAINER_ASO_ID__c)){
                            Integer iNext_ASO_Id = Integer.valueOf(currentNTASOId.CONTAINER_ASO_ID__c)+1;
                            if(String.valueOf(iNext_ASO_Id).length() == 3){
                                quote.CONTAINER_NT_Previous_ASO_ID__c = '0'+String.valueOf(iNext_ASO_Id) ;
                                quote.CONTAINER_ASO_ID__c ='0'+String.valueOf(iNext_ASO_Id);
                            }else if(String.valueOf(iNext_ASO_Id).length() == 2){
                                quote.CONTAINER_NT_Previous_ASO_ID__c = '00'+String.valueOf(iNext_ASO_Id) ;
                                quote.CONTAINER_ASO_ID__c ='00'+String.valueOf(iNext_ASO_Id);
                            }else if(String.valueOf(iNext_ASO_Id).length() == 1){
                                quote.CONTAINER_NT_Previous_ASO_ID__c = '000'+String.valueOf(iNext_ASO_Id) ;
                                quote.CONTAINER_ASO_ID__c ='000'+String.valueOf(iNext_ASO_Id);
                            }else {
                                quote.CONTAINER_NT_Previous_ASO_ID__c = String.valueOf(iNext_ASO_Id) ;
                                quote.CONTAINER_ASO_ID__c = String.valueOf(iNext_ASO_Id);
                            }
                            
                            quote.CONTAINER_Status__c = 'ASO Released';
                            quote.CONTAINER_QuotePath__c = 'ASO Released';
                            
                            
                            system.debug('-------updated record-----------');
                            system.debug('Previous ASO_ID ='+ quote.CONTAINER_NT_Previous_ASO_ID__c);
                            system.debug('ASO ID ='+quote.CONTAINER_ASO_ID__c);
                        }
                        
                        
                    }else If (quote.CONTAINER_ASO_ID__c <> null && quote.CONTAINER_ASO_Rev__c == null){
                        quote.CONTAINER_NT_RevNumber__c = 0;
                        quote.CONTAINER_ASO_Rev__c = mapQuoteRevNumbertoName.get(Integer.valueOf(quote.CONTAINER_NT_RevNumber__c));
                        quote.CONTAINER_Revision_Date__c = system.today();
                        system.debug('-------updated 1st Revision record-----------');
                        system.debug('GENSET RevNumber ='+quote.CONTAINER_NT_RevNumber__c);
                        system.debug('ASO REV = '+ quote.CONTAINER_ASO_Rev__c);
                    }else If (quote.CONTAINER_ASO_ID__c <> null && quote.CONTAINER_ASO_Rev__c <> null){
                        quote.CONTAINER_Revision_Date__c = system.today();
                        quote.CONTAINER_NT_RevNumber__c = quote.CONTAINER_NT_RevNumber__c +1;
                        quote.CONTAINER_ASO_Rev__c = mapQuoteRevNumbertoName.get(Integer.valueOf(quote.CONTAINER_NT_RevNumber__c));
                        system.debug('-------updated Revision record-----------');
                        system.debug('GENSET RevNumber ='+quote.CONTAINER_NT_RevNumber__c);
                        system.debug('ASO REV = '+ quote.CONTAINER_ASO_Rev__c);
                    }
                    quote.CONTAINER_IsRevised__c=TRUE;
                    lstQuote.add(quote);
                }     
            }
            
            if(lstQuote != null && lstQuote.size() > 0){
                update lstQuote ;
            }
        }
    }    
}