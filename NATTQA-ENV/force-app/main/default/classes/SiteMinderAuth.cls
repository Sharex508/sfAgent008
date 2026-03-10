global class SiteMinderAuth extends Auth.AuthProviderPluginClass {

    private String clientId;
    private String clientSecret;
    private String accessTokenUrl;
    private String authorizationUrl;
    private String scope;
    private String userInfoUrl;
    public String redirectUri;

    // This method is responsible for returning the custom metadata storing the api credentials and other details
    global String getCustomMetadataType() {
        return 'SiteminderCredential__mdt';
    }

    // This method is responsible to initiate the authorization code flow
    global PageReference initiate(Map<String, String> authProviderConfiguration, String stateToPropagate) {
        clientId = authProviderConfiguration.get('Client_Id__c');
        authorizationUrl = authProviderConfiguration.get('Authorization_URL__c');
        scope = EncodingUtil.urlEncode(authProviderConfiguration.get('Scope__c'),'UTF-8');
        redirectUri = authProviderConfiguration.get('Redirect_URI__c');
        System.debug('clientId:'+clientId);
        System.debug('authorizationUrl:'+authorizationUrl);
        System.debug('scope:'+scope);
        System.debug('redirectUri:'+redirectUri);
        System.debug('State Before decode:'+stateToPropagate);
        System.debug('State after decode:'+EncodingUtil.urlDecode(stateToPropagate, 'UTF-8'));
        System.debug('State after decode again:'+EncodingUtil.urlDecode(EncodingUtil.urlDecode(stateToPropagate, 'UTF-8'), 'UTF-8'));
        //uncommented by Rama Iyer - 10132022 as we are not going forward with www.carriersolutioncenter.com and using Salesforce community URL
        //String url = authorizationUrl + '?response_type=code&scope='+scope+'&client_id='+clientId+'&redirect_uri='+redirectUri+'&state='+stateToPropagate;
        // Code added to remove the last '=' as it was getting doubled encoded by SiteMinder generating State error.
        String url;
        if(stateToPropagate.contains('==')){
         url = authorizationUrl + '?response_type=code&scope='+scope+'&client_id='+clientId+'&redirect_uri='+redirectUri+'&state='+stateToPropagate.removeEnd('==');
        }
        else
        {
         url = authorizationUrl + '?response_type=code&scope='+scope+'&client_id='+clientId+'&redirect_uri='+redirectUri+'&state='+stateToPropagate.removeEnd('=');
        }
        //String url = authorizationUrl + '?response_type=code&scope='+scope+'&client_id='+clientId+'&redirect_uri='+redirectUri+'&state=Tejas';
        System.debug('initiate'+url);
        return new PageReference(url);
    }

    /*   
      This method is responsible to handle the callback from authorization code flow
      set the access token, refresh token and other parameters
    */
    global Auth.AuthProviderTokenResponse handleCallback(Map<String, String> authProviderConfiguration, Auth.AuthProviderCallbackState state) {
       System.debug('handleCallback authProviderConfiguration: '+authProviderConfiguration);
       System.debug('handleCallback authProviderCallbackState: '+state);
       clientId = authProviderConfiguration.get('Client_Id__c');
       clientSecret = authProviderConfiguration.get('Client_Secret__c');
       scope = authProviderConfiguration.get('Scope__c');
       redirectUri = authProviderConfiguration.get('Redirect_URI__c');
       accessTokenUrl = authProviderConfiguration.get('Access_Token_URL__c');
      
       
       Map<String,String> queryParams = state.queryParameters;
       String code = queryParams.get('code');
       String sfdcState = queryParams.get('state');       
       HttpRequest req = new HttpRequest();
       req.setEndpoint(accessTokenURL);
       req.setHeader('Accept','application/json');
       req.setMethod('POST');
 // new 5.21.2021
       String decode_state = EncodingUtil.urlDecode(EncodingUtil.urlDecode(sfdcstate, 'UTF-8'), 'UTF-8');
       req.setBody('client_id='+clientId+'&grant_type=authorization_code&client_secret='+clientSecret+'&code='+code+'&redirect_uri='+redirectUri+'&state='+decode_state);
       

       System.debug('handleCallback'+req.getBody());
       Http http = new Http();
       HTTPResponse res = http.send(req);
       String responseBody = res.getBody();
       System.debug('responseBody'+responseBody);
       SiteMinderResponse response = (SiteMinderResponse) JSON.deserialize(responseBody, SiteMinderResponse.class);
       
       return new Auth.AuthProviderTokenResponse('SiteMinderAuth', response.access_token, 'refreshToken', sfdcState);
    }

    // This method is responsible to get the user information used for authentication from the external api
    global Auth.UserData getUserInfo(Map<String, String> authProviderConfiguration, Auth.AuthProviderTokenResponse response) {

      userInfoUrl = authProviderConfiguration.get('User_Info_URL__c');
      String token = response.oauthToken;
      System.debug('TOKEN'+token);
      HttpRequest req = new HttpRequest();
      req.setHeader('Authorization', 'Bearer ' + token);
       //req.setHeader('Content-Type','application/xml');
      req.setHeader('Content-Type','application/xml');
      req.setEndpoint(userInfoUrl);
      req.setMethod('GET');
      //req.setMethod('POST');

      Http http = new Http();
      HTTPResponse res = http.send(req);
      String responseBody = res.getBody();
      System.debug('responseBody'+responseBody);
      SiteMinderUserInfoResponse infoApiResponse = (SiteMinderUserInfoResponse) JSON.deserialize(responseBody, SiteMinderUserInfoResponse.class);
      String userId, fullName, firstName, lastName, locale, loginURL, email;
      locale = 'en-US';
      loginURL = authProviderConfiguration.get('Login_URL__c');
      email = infoApiResponse.email;
      userId = infoApiResponse.uid;
      fullName = infoApiResponse.firstName+ ' ' + infoApiResponse.lastName;
      firstName = infoApiResponse.firstName;
      lastName = infoApiResponse.lastName; 
      //Added by Rama Iyer 02/24/2020 to fix SSO Issue
         Map<String,String> provMap = new Map<String,String>();
         provMap.put('what1', 'noidea1');
         provMap.put('what2', 'noidea2');
      Auth.UserData ud = new Auth.UserData(
        userId,
        firstName,
        lastName,
        fullName,
        email,
        'https://carstage-transicoldtest.cs201.force.com/', 
        email,
        locale,
        'SiteMinder',
        loginURL,
        provMap
      );
      System.debug('UserData: '+ud);
      return ud;
    }

    // Wrapper class to handle User Info API response
    public class SiteMinderUserInfoResponse {
      public String email;
      public String firstname;
      public String lastname;
      public String uid;
    }

    // Wrapper class to handle Access Token API response
    public class SiteMinderResponse {
      public String access_token;
      public String token_type;
        public String id_token;
      public String scope;
    }

}