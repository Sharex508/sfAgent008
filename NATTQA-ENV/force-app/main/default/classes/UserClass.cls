/*************************************************************************************************
Apex Class Name : UserClass
Version : 1.0
Created Date : 15/03/2023
Function : To automatically assign chatter group to newly created user based on Chatter Group Profile CustomSetting records

Modification Log:
-------------------------------------------------------------------------------------------------------------------------------------------------
* Developer                                Date                                Description
* -----------------------------------------------------------------------------------------------------------------------------------------------
* Sanjay Sarraf         		     15/03/2023                        Initial creation        
*************************************************************************************************/
public class UserClass {
	
	public static Map<String,Set<String>> getMapofChatterAndRltdProfile(){
		//Map to store profile Name and related Chatter Group Set
		Map<String,Set<String>> mapProfileToChatterGrpNames=new Map<String,Set<String>>();
		List<ChatterGroupProfileCustomSetting__c> csList=[SELECT Name,ChatterGroupNames__c from ChatterGroupProfileCustomSetting__c];
		if(!csList.isEmpty()){
			for(ChatterGroupProfileCustomSetting__c csRcd:csList){
				Set<String> chatterSet = new Set<String>();
				if(mapProfileToChatterGrpNames.containsKey(csRcd.Name)){
					chatterSet=mapProfileToChatterGrpNames.get(csRcd.Name);           
					
				}				
				for(String s:csRcd.ChatterGroupNames__c.split('\n')){
                    chatterSet.add(s.trim());					
				}
                mapProfileToChatterGrpNames.put(csRcd.Name,chatterSet);
			}
			return mapProfileToChatterGrpNames;
		}
		return mapProfileToChatterGrpNames;
	}
	public static void addNewUserInGroup(List<User> userRcdList){
		// to store all the user where we changed notification frequency
        List<user> userLstFrUpd = new List<user>();
		Set<id> userIdSet = new Set<id>();
		//Map to store profile and related Chatter Groups based out of ChatterGroupProfileCustomSetting__c
		Map<String,Set<String>> profileToChatterGrpNamesMap = new Map<String,Set<String>>();		
		profileToChatterGrpNamesMap = UserClass.getMapofChatterAndRltdProfile();
		if(!userRcdList.isEmpty() && profileToChatterGrpNamesMap.keySet().size()>0){
            list<user> existingUserList = [select id, profile.name from User where id IN :userRcdList];
			// loop the users that have been created
			 for(User usrInst : existingUserList){
				if(profileToChatterGrpNamesMap.containsKey(usrInst.Profile.Name)){
                    User usr  = new User(Id = usrInst.Id);
					usr.DefaultGroupNotificationFrequency = 'P';
					userLstFrUpd.add(usr);
					userIdSet.add(usrInst.id);
                    //system.debug('Testusercheck' +userIdSet);
				}
			 }
		}
        //system.debug('testlist07' +userLstFrUpd);
		if(!userLstFrUpd.isEmpty()){
			update userLstFrUpd;
            //system.debug('Testpoc1' +userIdSet);
			UserClass.AddToChatterGroups(userIdSet);
		}
		 
	}
	
	
	// Method to assign newly created user's to Chatter Group based on ChatterGroupProfileCustomSetting__c
	@future
	public static void AddToChatterGroups(Set<Id> userIds){
		//fetching users List using userIdSet
        List<User> userList=[select id, Username,Profile.name from User where id in :userIds];
        
        //system.debug('Testpoc2' +userList);
        
		//fetching all the chatter groups present in org
        List<CollaborationGroup> chatterGroupList=[select id, Name from CollaborationGroup];
        //system.debug('Testpoc3' +chatterGroupList);
		
		// List to store chatter group member details that needed to be inserted for all newly created user
        List<CollaborationGroupMember> chatterGroupMembersList=new List<CollaborationGroupMember>();
		//Map to store profile and related Chatter Groups
		Map<String,Set<String>> profileToChatterGrpNamesMap=new Map<String,Set<String>>();		
		profileToChatterGrpNamesMap = UserClass.getMapofChatterAndRltdProfile();
		
        //system.debug('profileChatterMap -'+profileToChatterGrpNamesMap);
		
		//Map to store Chatter Group Name with the corresponding detail record
        Map<String,CollaborationGroup> mapNameToGrp=new Map<String,CollaborationGroup>();		
		if(!chatterGroupList.isEmpty()){
			for(CollaborationGroup cg:chatterGroupList){
				mapNameToGrp.put(cg.name,cg);
			}
		}
		//List to store existing chatter group member details
		List<CollaborationGroupMember> groupMembers=new List<CollaborationGroupMember>();
        if(mapNameToGrp.keySet().size()>0){
			groupMembers=[Select Id,MemberId,CollaborationGroup.Name from CollaborationGroupMember where CollaborationGroup.Name In :mapNameToGrp.keySet()];
		}
        //system.debug('testlist03 -'+groupMembers);
		
		// map of user Id to related List of Chatter Group
		Map<String,Set<String>> mapUserToGroupName=new Map<String,Set<String>>(); 
		if(!groupMembers.isEmpty()){
			for(CollaborationGroupMember cgm :groupMembers){
				if(!mapUserToGroupName.containsKey(cgm.MemberId)){
					mapUserToGroupName.put(cgm.MemberId, new Set<String>{cgm.CollaborationGroup.Name});
					
				}else{
					mapUserToGroupName.get(cgm.MemberId).add(cgm.CollaborationGroup.Name);
				}
				
			}
		}
         
       
		// iterating over List of newly created user's 
        for (User usr : userList){
			// checking if newly created user profile name present in profileToChatterGrpNamesMap
			if(profileToChatterGrpNamesMap.containsKey(usr.Profile.Name)){
				// iterating over group Name Set 
				for(String gr:profileToChatterGrpNamesMap.get(usr.Profile.Name)){
					CollaborationGroupMember cbm= new CollaborationGroupMember();
                    if(mapNameToGrp.containsKey(gr.trim()) && (!mapUserToGroupName.containsKey(usr.Id) || (mapUserToGroupName.containsKey(usr.Id) 
                       && !mapUserToGroupName.get(usr.Id).contains(gr.trim())))){
						// adding each user to corresponding chatter group
						cbm.CollaborationGroupId=mapNameToGrp.get(gr.trim()).Id;                
						cbm.MemberId=usr.Id;
						chatterGroupMembersList.add(cbm);
					}

				}
			}			
          system.debug('testlist05 -'+chatterGroupMembersList);  
        }
		if(!chatterGroupMembersList.isEmpty()){
			insert chatterGroupMembersList;
		}	 
	 
	 
	}
    
    
}