/*************************************************************************************************
Apex Class Name : BatchAssignChatterGroupToUsers
Version : 1.0
Created Date : 05/04/2023
Function : To automatically assign chatter group to existing user based on Chatter Group Profile CustomSetting records

Modification Log:
-------------------------------------------------------------------------------------------------------------------------------------------------
* Developer                                Date                                Description
* -----------------------------------------------------------------------------------------------------------------------------------------------
* Sanjay Sarraf         		     05/04/2023                        Initial creation        
*************************************************************************************************/
public class BatchAssignChatterGroupToUsers implements Database.Batchable<SObject>,Database.Stateful {
    Map<String,Set<String>> mapProfileToChatterGrpNames=new Map<String,Set<String>>(); // map of profile and List of Chatter Group Name
    Map<String,CollaborationGroup> mapNameToGrp=new Map<String,CollaborationGroup>(); // map of chatter group name and record of chatter group
    Map<String,Set<String>> mapUserToGroupName=new Map<String,Set<String>>(); // map of user Id to List of Group
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
		List<CollaborationGroup> chatterGroups=new List<CollaborationGroup>();
		List<CollaborationGroupMember> groupMembers=new List<CollaborationGroupMember>();
        List<ChatterGroupProfileCustomSetting__c> csList=[SELECT Name,ChatterGroupNames__c from ChatterGroupProfileCustomSetting__c]; 
        Set<String> profiles=new Set<String>();
        Set<String> cnames=new Set<String>();
		if(!csList.isEmpty()){
			for(ChatterGroupProfileCustomSetting__c cSetting:csList){
				if(!String.isBlank(cSetting.ChatterGroupNames__c)){                
					Set<String> chatterSet = new Set<String>();
					for(String s:cSetting.ChatterGroupNames__c.split('\n')){
						chatterSet.add(s.trim());
						profiles.add(cSetting.Name);
						cnames.add(s.trim());
					}
					mapProfileToChatterGrpNames.put(cSetting.Name,chatterSet);
				}
			}
		}
        
		if(!cnames.isEmpty()){
			chatterGroups=[Select Id,Name from CollaborationGroup where Name IN :cnames];
		}
        if(!chatterGroups.isEmpty()){
			for(CollaborationGroup cg:chatterGroups){
				mapNameToGrp.put(cg.name,cg);
			}
		}
		
        if(mapNameToGrp.keySet().size()>0){
			groupMembers=[Select Id,MemberId,CollaborationGroup.Name from CollaborationGroupMember where CollaborationGroup.Name In :mapNameToGrp.keySet()];
		}
        if(!groupMembers.isEmpty()){
			for(CollaborationGroupMember member:groupMembers){
				if(!mapUserToGroupName.containsKey(member.MemberId)){
					mapUserToGroupName.put(member.MemberId, new Set<String>{member.CollaborationGroup.Name});
					
				}else{
					mapUserToGroupName.get(member.MemberId).add(member.CollaborationGroup.Name);
				}
				
			}
		}
        
        System.debug('Map chatter group--'+mapNameToGrp);
        boolean isActive=true;
        String query = 'SELECT Id, ProfileId,Profile.Name,Name FROM User WHERE isActive='+isActive+' and Profile.Name  IN :Profiles';
        return Database.getQueryLocator(query);
    }
    
	public void execute(Database.BatchableContext bc, List<User> scope) {
        List<CollaborationGroupMember> cbmGrpList=new List<CollaborationGroupMember>();
        for (User  u:scope) {
            if(mapProfileToChatterGrpNames.containsKey(u.Profile.Name)){
                Set<String> groups=mapProfileToChatterGrpNames.get(u.Profile.Name);
                for(String s:groups){
                    CollaborationGroupMember cbm= new CollaborationGroupMember();
                    if(mapNameToGrp.containsKey(s) && (!mapUserToGroupName.containsKey(u.Id) || (mapUserToGroupName.containsKey(u.Id) && !mapUserToGroupName.get(u.Id).contains(s)))){
                        cbm.CollaborationGroupId=mapNameToGrp.get(s).Id;                
                        cbm.MemberId=u.Id;
                        cbmGrpList.add(cbm);
                    }

                }
                
            }
            
        }
        if(!cbmGrpList.isEmpty()){
            try{
                insert cbmGrpList;
            }
            catch(Exception e){
                System.debug('Error is--- '+e.getMessage());
            }
            
        }
    }
    
    public void finish(Database.BatchableContext bc) {
         System.debug('');
    }
    
}