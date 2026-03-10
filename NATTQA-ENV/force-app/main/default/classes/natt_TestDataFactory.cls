public class natt_TestDataFactory {
    public static User createUser(string userName, string profileName, string alias) {
        Profile profile = [SELECT Id FROM Profile WHERE Name =: profileName LIMIT 1];
        User user = new User(
            FirstName = 'Test',
            LastName = userName,
            Username = 'testuser' + userName + '@example.com',
            Email = 'testuser' +userName + '@example.com',
            Alias = alias,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = profile.Id
            //RoleId = roleId
        );
        return user;
    }
    
    public static UserRole createRole() {
        UserRole role = new UserRole(
            Name = 'Test Role',
            DeveloperName = 'Test_Role'
        );
        return role;
    }
    
    public static Account createAccount(string name, Id recordtypeId) {
        Account account = new Account(
            Name = name,
            NATT_Region__c = 'East',
            RecordTypeId = recordtypeId,
            NATT_Organization__c = 'NATT'            
        );
        return account;
    }
    
    public static Contact createContact(Id accountId,string lastName, Id RecordTypeId) {
        Contact contact = new Contact(
            FirstName = 'Test',
            LastName = lastName,
            AccountId = accountId,
            Phone = '123-456-7890',
            RecordTypeId = RecordTypeId,
            NATT_Key_Business_Role__c = 'Principal',
            Email = 'testcontact' + lastName + '@example.com'
        );
        return contact;
    }
    
    public static Order createOrder(Id accountId,Id recordTypeId) {
        Order order = new Order(
            Type = 'Stock',
            Status = 'Draft',
            AccountId = accountId,
            NATT_Purchase_Order__c= '1234',
            NATT_Shipment_Terms__c = 'PPD',
            EffectiveDate = System.today(),
            NATT_JDE_Sales_Order_Number__c = '555',
            OrderedDate = (DateTime)System.today()             
        );
        return order;
    }
    
    
    public static OrderItem createOrderItem(Id orderId, Id productId, Decimal quantity) {
        //PricebookEntry pricebookEntry = [SELECT Id, UnitPrice FROM PricebookEntry WHERE IsActive = true LIMIT 1];
        OrderItem ordItem = new OrderItem(        	
            Quantity = 4,
            UnitPrice = 2,
            ListPrice = 123,
            LineNumber = 10,
            OrderId = orderId,
            Product2Id = productId,
            NATT_Backordered_Quantity__c = quantity
        );
        return ordItem;
    }
    
    public static Product2 createProduct(string name,string pin) {
        Product2 testProduct = new Product2(
            Name = name,
            NATT_P_N__c = pin        
        );
        return testProduct;
    }
}