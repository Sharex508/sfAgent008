public with sharing class NATT_ShowAccountHierarchyController {

    public static String recordId;
    public static List<String> ltExpandedRows = new List<String>();
    public static Account currentAccount = new Account();
    public static List<AccountHierarchy> ltAccountHierarchy = new List<AccountHierarchy>();
    public static AccountHierarchy parentOneCurrentAccount = new AccountHierarchy();
    public static AccountHierarchy parentTwoCurrentAccount = new AccountHierarchy();
    public static AccountHierarchy parentThreeCurrentAccount = new AccountHierarchy();
    public static AccountHierarchy parentFourCurrentAccount = new AccountHierarchy();
    public static AccountHierarchy parentFiveCurrentAccount = new AccountHierarchy();
    
    @AuraEnabled
    public static Map<String, Object> getAccountHierarchy(Id recordId) {
        Map<String, Object> mpReturn = new Map<String, Object>{'success' => true, 'message' => ''};

        try {
            
            if (recordId == null) throw new AuraHandledException('Invalid Parameter!');

            mpReturn.put('data', fetchAccountHierarchy(recordId));
            mpReturn.put('ltExpandedRows', ltExpandedRows);

        } catch (AuraHandledException e) {
            mpReturn.put('success', false);
            mpReturn.put('message', e.getMessage());
        }
        
        return mpReturn;
    }

    @TestVisible
    private static List<AccountHierarchy> fetchAccountHierarchy(String recordId) {        
        List<Account> ltCurrentAccount = [
            SELECT Id, Name, NATT_City_State__c, NATT_Status__c, NATT_Primary_Location_Type__c, ParentId,
                    Parent.Name, Parent.NATT_City_State__c, Parent.NATT_Status__c, Parent.NATT_Primary_Location_Type__c,
                    Parent.Parent.Name, Parent.Parent.NATT_City_State__c, Parent.Parent.NATT_Status__c, Parent.Parent.NATT_Primary_Location_Type__c,
                    Parent.Parent.Parent.Name, Parent.Parent.Parent.NATT_City_State__c, Parent.Parent.Parent.NATT_Status__c, Parent.Parent.Parent.NATT_Primary_Location_Type__c,
                    Parent.Parent.Parent.Parent.Name, Parent.Parent.Parent.Parent.NATT_City_State__c, Parent.Parent.Parent.Parent.NATT_Status__c, Parent.Parent.Parent.Parent.NATT_Primary_Location_Type__c,
                    Parent.Parent.Parent.Parent.Parent.Name, Parent.Parent.Parent.Parent.Parent.NATT_City_State__c, Parent.Parent.Parent.Parent.Parent.NATT_Status__c, Parent.Parent.Parent.Parent.Parent.NATT_Primary_Location_Type__c
            FROM Account
            WHERE ID =:recordId
            AND NATT_Status__c = :NATT_Constants.ACCOUNT_ACTIVE
            LIMIT 1
        ];

        if (ltCurrentAccount.isEmpty()) return ltAccountHierarchy;
        
        currentAccount = ltCurrentAccount.get(0);
        ltExpandedRows.add(currentAccount.Name);
        
        AccountHierarchy actualAccountHierarchy = getAccountHierarchyObject(currentAccount, true, '', null);
        ltAccountHierarchy.add(actualAccountHierarchy);
        
        Map<Id, Account> mpChildCurrentAccount = new Map<Id, Account>([SELECT Id, Name, ParentId, NATT_City_State__c, NATT_Status__c, NATT_Primary_Location_Type__c FROM Account WHERE ParentId = :recordId AND NATT_Status__c = :NATT_Constants.ACCOUNT_ACTIVE]);
        
        List<AccountHierarchy> ltChildAccountHierarchy = getChildrenAndStepSon(mpChildCurrentAccount);

        if (!ltChildAccountHierarchy.isEmpty()) {
            if (actualAccountHierarchy.ltChildren != null) {
                actualAccountHierarchy.ltChildren.addAll(ltChildAccountHierarchy);
            } else {
                actualAccountHierarchy.ltChildren = ltChildAccountHierarchy;
            }
        }

        setParentLevels(actualAccountHierarchy, currentAccount);

        return ltAccountHierarchy;
    }

    private static List<AccountHierarchy> getChildrenAndStepSon(Map<Id, Account> mpAccountsById) {
        Map<Id, List<Account>> mpStepSonByFather = buildMapChildrenByFather(mpAccountsById.keySet());
        List<AccountHierarchy> ltChildAccountHierarchy = new List<AccountHierarchy>();

        for (Account child : mpAccountsById.values()) {
            List<AccountHierarchy> ltStepSonAccountHierarchy = new List<AccountHierarchy>();
            AccountHierarchy childAccountHierarchy = getAccountHierarchyObject(child, false, 'below', null);
            
            if (mpStepSonByFather.containsKey(child.Id)) {
                for (Account stepSon : mpStepSonByFather.get(child.Id)) {
                    ltStepSonAccountHierarchy.add(getAccountHierarchyObject(stepSon, false, 'below', null));
                }
            }

            if (!ltStepSonAccountHierarchy.isEmpty()) {
                childAccountHierarchy.ltChildren = ltStepSonAccountHierarchy;
            }

            ltChildAccountHierarchy.add(childAccountHierarchy);
        }

        return ltChildAccountHierarchy;
    }

    @TestVisible
    private static void setParentLevels(AccountHierarchy actualAccountHierarchy, Account currentAccount) {
        // Check if it's nedeed to go depper than 5 levels parent
        
        // parent 1
        if (currentAccount.ParentId != null) {
            Account parentOne = currentAccount.Parent; 
            ltExpandedRows.add(parentOne.Name); 
            List<AccountHierarchy> ltChildrenParentOne = new List<AccountHierarchy>{actualAccountHierarchy};
            ltChildrenParentOne.addAll(getBrothers(currentAccount));

            parentOneCurrentAccount = getAccountHierarchyObject(                
                parentOne,
                false,
                'above',
                ltChildrenParentOne
            );

            ltAccountHierarchy.clear();
            ltAccountHierarchy.add(parentOneCurrentAccount);

            // parent 2
            if (currentAccount.Parent.ParentId != null) {
                Account parentTwo = currentAccount.Parent.Parent;
                ltExpandedRows.add(parentTwo.Name);  
                List<AccountHierarchy> ltChildrenParentTwo = new List<AccountHierarchy>{parentOneCurrentAccount};
                ltChildrenParentTwo.addAll(getBrothers(currentAccount.Parent));
                
                parentTwoCurrentAccount = getAccountHierarchyObject(                    
                    parentTwo,
                    false,
                    'above',
                    ltChildrenParentTwo
                );
                    
                ltAccountHierarchy.clear();
                ltAccountHierarchy.add(parentTwoCurrentAccount);

                // parent 3
                if (currentAccount.Parent.Parent.ParentId != null) {
                    Account parentThree = currentAccount.Parent.Parent.Parent;
                    ltExpandedRows.add(parentThree.Name);
                    List<AccountHierarchy> ltChildrenParentThree = new List<AccountHierarchy>{parentTwoCurrentAccount};
                    ltChildrenParentThree.addAll(getBrothers(currentAccount.Parent.Parent));
                
                    parentThreeCurrentAccount = getAccountHierarchyObject(                       
                        parentThree,
                        false,
                        'above',
                        ltChildrenParentThree
                    );

                    ltAccountHierarchy.clear();
                    ltAccountHierarchy.add(parentThreeCurrentAccount);

                    // parent 4
                    if (currentAccount.Parent.Parent.Parent.ParentId != null) {
                        Account parentFour = currentAccount.Parent.Parent.Parent.Parent;
                        ltExpandedRows.add(parentFour.Name);
                        List<AccountHierarchy> ltChildrenParentFour = new List<AccountHierarchy>{parentThreeCurrentAccount};
                        ltChildrenParentFour.addAll(getBrothers(currentAccount.Parent.Parent.Parent));
                        
                        parentFourCurrentAccount = getAccountHierarchyObject(                            
                            parentFour,
                            false,
                            'above',
                            ltChildrenParentFour
                        );

                        ltAccountHierarchy.clear();
                        ltAccountHierarchy.add(parentFourCurrentAccount);

                        // parent 5
                        if (currentAccount.Parent.Parent.Parent.Parent.ParentId != null) {
                            Account parentFive = currentAccount.Parent.Parent.Parent.Parent.Parent;
                            ltExpandedRows.add(parentFive.Name);
                            List<AccountHierarchy> ltChildrenParentFive = new List<AccountHierarchy>{parentFourCurrentAccount};
                            ltChildrenParentFive.addAll(getBrothers(currentAccount.Parent.Parent.Parent.Parent));

                            Account parentFiveAccount = [
                                SELECT Id, Name, NATT_City_State__c, NATT_Status__c, NATT_Dealer_Principal__r.Name, Owner.Name, ParentId, NATT_Primary_Location_Type__c,
                                    Parent.Name, Parent.NATT_City_State__c, Parent.NATT_Status__c, Parent.NATT_Dealer_Principal__r.Name, Parent.Owner.Name, Parent.NATT_Primary_Location_Type__c,
                                    Parent.Parent.Name, Parent.Parent.NATT_City_State__c, Parent.Parent.NATT_Status__c, Parent.Parent.NATT_Dealer_Principal__r.Name, Parent.Parent.Owner.Name, Parent.Parent.NATT_Primary_Location_Type__c,
                                    Parent.Parent.Parent.Name, Parent.Parent.Parent.NATT_City_State__c, Parent.Parent.Parent.NATT_Status__c, Parent.Parent.Parent.NATT_Dealer_Principal__r.Name, Parent.Parent.Parent.Owner.Name, Parent.Parent.Parent.NATT_Primary_Location_Type__c,
                                    Parent.Parent.Parent.Parent.Name, Parent.Parent.Parent.Parent.NATT_City_State__c, Parent.Parent.Parent.Parent.NATT_Status__c, Parent.Parent.Parent.Parent.NATT_Dealer_Principal__r.Name, Parent.Parent.Parent.Parent.Owner.Name, Parent.Parent.Parent.Parent.NATT_Primary_Location_Type__c,
                                    Parent.Parent.Parent.Parent.Parent.Name, Parent.Parent.Parent.Parent.Parent.NATT_City_State__c, Parent.Parent.Parent.Parent.Parent.NATT_Status__c, Parent.Parent.Parent.Parent.Parent.Owner.Name, Parent.Parent.Parent.Parent.Parent.NATT_Primary_Location_Type__c
                                FROM Account
                                WHERE ID =:parentFive.Id
                                AND NATT_Status__c =: NATT_Constants.ACCOUNT_ACTIVE
                                LIMIT 1
                            ];
                            
                            parentFiveCurrentAccount = getAccountHierarchyObject(                                
                                parentFiveAccount,
                                false,
                                'above',
                                ltChildrenParentFive
                            );
                                
                            ltAccountHierarchy.clear();
                            ltAccountHierarchy.add(parentFiveCurrentAccount);

                            if (parentFiveAccount.ParentId != null) {
                                setParentLevels(parentFiveCurrentAccount, parentFiveAccount);
                            }
                        }
                    }

                }
            
            }
        }
    }

    private static List<AccountHierarchy> getBrothers(Account currentAccount) {
        Map<Id, Account> mpBrotherAccount = new Map<Id, Account>([SELECT Id, Name, ParentId, NATT_City_State__c, NATT_Status__c, NATT_Primary_Location_Type__c FROM Account WHERE ParentId = :currentAccount.ParentId AND Id != :currentAccount.Id AND NATT_Status__c = :NATT_Constants.ACCOUNT_ACTIVE]);
        List<AccountHierarchy> ltBrotherAccountHierarchy = new List<AccountHierarchy>();

        return getChildrenAndStepSon(mpBrotherAccount);
    }

    @TestVisible
    private static AccountHierarchy getAccountHierarchyObject(Account acc, Boolean isCurrent, String position, List<AccountHierarchy> ltAccountHierarchy) {
        AccountHierarchy accHierarchy = new AccountHierarchy();

        accHierarchy.name = acc.Name;
        accHierarchy.isCurrent = isCurrent;
        accHierarchy.cityState = acc.NATT_City_State__c;
        accHierarchy.primaryLocationType = acc.NATT_Primary_Location_Type__c;
        accHierarchy.status = acc.NATT_Status__c;
        accHierarchy.url = URL.getSalesforceBaseUrl().toExternalForm() + '/' + acc.Id;
        accHierarchy.iconName = isCurrent ? 'standard:account' : '';
        accHierarchy.position = position;

        if (ltAccountHierarchy != null) {
            accHierarchy.ltChildren = ltAccountHierarchy;
        } else {
            accHierarchy.ltChildren = null;
        }

        return accHierarchy;
    }

    @TestVisible
    private static Map<Id, List<Account>> buildMapChildrenByFather(Set<Id> parentIds) {
        
        Map<Id, List<Account>> mpChildrenByFather = new Map<Id, List<Account>>();

        for (Account acc : [SELECT Id, Name, ParentId, NATT_City_State__c, NATT_Status__c, NATT_Primary_Location_Type__c FROM Account WHERE ParentId IN :parentIds AND NATT_Status__c =: NATT_Constants.ACCOUNT_ACTIVE]){
            if (mpChildrenByFather.containsKey(acc.ParentId)) {
                mpChildrenByFather.get(acc.ParentId).add(acc);
            } else {
                List<Account> ltAcc = new List<Account>();
                ltAcc.add(acc);

                mpChildrenByFather.put(acc.ParentId, ltAcc);
            }
        }

        return mpChildrenByFather;
    }

    @AuraEnabled
    public static Map<String, Object> getNewChildren(String accountName) {
        Map<String, Object> mpReturn = new Map<String, Object>{'success' => true, 'message' => ''};
        List<AccountHierarchy> ltChildAccountHierarchy = new List<AccountHierarchy>();

        try {

            Account acc = [SELECT Id FROM Account WHERE Name =: accountName];
            Map<Id, Account> mpIdAccount = new Map<Id, Account>([SELECT Id, Name, ParentId, NATT_City_State__c, NATT_Status__c, NATT_Primary_Location_Type__c FROM Account WHERE ParentId =: acc.Id AND NATT_Status__c =: NATT_Constants.ACCOUNT_ACTIVE]);
            Map<Id, List<Account>> mpStepSonByFather = buildMapChildrenByFather(mpIdAccount.keySet());
            
            for (Account accChild : mpIdAccount.values()) {
                List<AccountHierarchy> ltStepSonAccountHierarchy = new List<AccountHierarchy>();

                AccountHierarchy childAccountHierarchy = getAccountHierarchyObject(accChild, false, 'below', null);
                
                if (mpStepSonByFather.containsKey(accChild.Id)) {
                    for (Account stepSon : mpStepSonByFather.get(accChild.Id)) {
                        ltStepSonAccountHierarchy.add(getAccountHierarchyObject(stepSon, false, 'below', null));
                    }
                }

                if (!ltStepSonAccountHierarchy.isEmpty()) {
                    childAccountHierarchy.ltChildren = ltStepSonAccountHierarchy;
                }
                
                ltChildAccountHierarchy.add(childAccountHierarchy);
            }

            mpReturn.put('data', new Map<String, List<AccountHierarchy>>{accountName => ltChildAccountHierarchy});

        } catch (AuraHandledException e) {
            mpReturn.put('success', false);
            mpReturn.put('message', e.getMessage());
        }
        
        return mpReturn;
    }

    public class AccountHierarchy {
        @AuraEnabled public String name;
        @AuraEnabled public Boolean isCurrent = false;
        @AuraEnabled public String cityState;
        @AuraEnabled public String primaryLocationType;
        @AuraEnabled public String status;
        @AuraEnabled public String url;
        @AuraEnabled public String iconName = '';
        @AuraEnabled public String position = '';
        @AuraEnabled public List<AccountHierarchy> ltChildren;
    }

}