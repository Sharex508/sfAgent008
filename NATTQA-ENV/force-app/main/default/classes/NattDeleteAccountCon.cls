public without sharing class NattDeleteAccountCon {
	@AuraEnabled
    public static boolean deleteAccount(String recordId){
        try{            
            User u = [SELECT Id,Profile.Name,ContactId FROM User WHERE Id=:UserInfo.getUserId()];
            Set<String> userProfileSet = new Set<String>(NATT_CONSTANTS.NATT_USER_PROFILE_LIST);
            if(userProfileSet.contains('NATT Accounts Read Only'))
                userProfileSet.remove('NATT Accounts Read Only');
            if(userProfileSet.contains(u.Profile.Name)){
        		delete new Account(Id=recordId);
            }else{
                throw new AuraHandledException('You do not have permission to delete this account.');                
            }
            //checks to see if the user is a portal user
            return String.isNotEmpty(u.ContactId);
        }catch(DMLException dmle){
            throw new AuraHandledException(dmle.getDmlMessage(0));
        }        
    }
}