public without sharing class NATT_EmailVerifications {
    
      @AuraEnabled
    public static String  InitiateEmailVerification(Id UserId)
    {
       
        System.UserManagement.sendAsyncEmailConfirmation(UserId, null, null,null);
		return 'Data processed successfully!';
    }

}