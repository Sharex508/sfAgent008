global class SimpleRegHanlder implements Auth.RegistrationHandler{
    class RegHandlerException extends Exception {}
    global User createUser(Id portalId, Auth.UserData data){       
        try{
            User u = [SELECT ID FROM User Where FederationIdentifier = :data.identifier limit 1];
            return u;
            
        } catch (Exception e){
            throw new RegHandlerException('Cannot find this user. For help, contact your administrator.');
        }
    }
    global void updateUser(Id userId, Id portalId, Auth.UserData data){ 
        try{
            system.debug('In Update User with'+data.email);
            User u = [SELECT ID FROM User Where FederationIdentifier = :data.identifier limit 1];
            Update u;
            
        } catch (Exception e){
            throw new RegHandlerException('Cannot find this user. For help, contact your administrator 2.');
        }
    }
}