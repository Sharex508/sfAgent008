public without sharing class NATT_SBQQ{  
    
    public static QuoteModel readQuote(String quoteId) {
        String quoteJSON = SBQQ.ServiceRouter.read('SBQQ.QuoteAPI.QuoteReader', quoteId);
        return (QuoteModel) JSON.deserialize(quoteJSON, QuoteModel.class);
    }
    
    public static void calculateQuote(QuoteModel quote) {
        QuoteCalculatorContext ctx = new QuoteCalculatorContext(quote, 'NATT_SBQQCalculateCallback');
        SBQQ.ServiceRouter.load('SBQQ.QuoteAPI.QuoteCalculator', null, JSON.serialize(ctx));    
    }  
    
    private class QuoteCalculatorContext {        
        private QuoteModel quote;             //The quote and callbackClass properties are called in the API code by the exact names seen here.
        private String callbackClass;         //Altering these property names will cause calculator API calls to fail.
        
        private QuoteCalculatorContext(QuoteModel quote, String callbackClass) {
            this.quote = quote;            
            this.callbackClass = callbackClass;        
        }
    }
    
    public class QuoteModel {
        public SBQQ__Quote__c record;
        public QuoteLineModel[] lineItems;
        public QuoteLineGroupModel[] lineItemGroups;
        public Integer nextKey;
        public Boolean applyAdditionalDiscountLast;
        public Boolean applyPartnerDiscountFirst;
        public Boolean channelDiscountsOffList;
        public Decimal customerTotal;
        public Decimal netTotal;
        public Decimal netNonSegmentTotal;
    } 
    
    public class QuoteLineModel {
        public SBQQ__QuoteLine__c record;
        public Boolean amountDiscountProrated;
        public Integer parentGroupKey;
        public Integer parentItemKey;
        public Integer key;
        public Boolean upliftable;
        public String configurationType;
        public String configurationEvent;
        public Boolean reconfigurationDisabled;
        public Boolean descriptionLocked;
        public Boolean productQuantityEditable;
        public Decimal productQuantityScale;
        public String dimensionType;
        public Boolean productHasDimensions;
        public Decimal targetCustomerAmount;
        public Decimal targetCustomerTotal;
    }
    
    public class QuoteLineGroupModel {
        public SBQQ__QuoteLineGroup__c record;
        public Decimal netNonSegmentTotal;
        public Integer key;
    }
    
    public class QuoteProposalModel {
        public String name;
        public Id quoteId;
        public Id templateId;
        public String language;
        public String outputFormat;
        public String paperSize;
    }
    
    /*
    public static QuoteModel saveQuote(QuoteModel quote){
        String quoteJSON = SBQQ.ServiceRouter.save('SBQQ.QuoteAPI.QuoteSaver', JSON.serialize(quote));
        return (QuoteModel) JSON.deserialize(quoteJSON, QuoteModel.class);
    }
    
    
    public static ProductModel readProduct(Id productId, Id pricebookId, String currencyCode) {
        ProductReaderContext ctx = new ProductReaderContext(pricebookId, currencyCode);
        String productJSON = SBQQ.ServiceRouter.load('SBQQ.ProductAPI.ProductLoader', productId, JSON.serialize(ctx));
        System.debug('productJSON =>'+productJSON);
        return (ProductModel) JSON.deserialize(productJSON, ProductModel.class);
    }
    
    public static QuoteModel addProduct(QuoteModel quote, ProductModel[] products, Integer groupKey) {
        AddProductsContext ctx = new AddProductsContext(quote, products, groupKey);
        String quoteJSON = SBQQ.ServiceRouter.load('SBQQ.QuoteAPI.QuoteProductAdder', null, JSON.serialize(ctx));
        System.debug('quoteJSON =>'+quoteJSON);
        return (QuoteModel) JSON.deserialize(quoteJSON, QuoteModel.class);
    }     
    
    private class AddProductsContext {
        private QuoteModel quote;
        private ProductModel[] products;
        private Integer groupKey;
        // must be hardcoded to true
        private final Boolean ignoreCalculate = true; 
        
        private AddProductsContext(QuoteModel quote, ProductModel[] products, Integer groupKey) {
            this.quote = quote;
            this.products = products;
            this.groupKey = groupKey;
        }
    }
    
    private class ProductReaderContext {
        private Id pricebookId;
        private String currencyCode;
        
        private ProductReaderContext(Id pricebookId, String currencyCode) {
            this.pricebookId = pricebookId;
            this.currencyCode = currencyCode;
        }
    } 
    
    public class ProductModel {
        public Product2 record;
        public Id upgradedAssetId;
        public String currencySymbol;
        public String currencyCode;
        public String[] featureCategories;
        public FeatureModel[] features;
        public OptionModel[] options;
        public ConfigurationModel configuration;
        public ConfigAttributeModel[] configurationAttributes;
        public ConfigAttributeModel[] inheritedConfigurationAttributes;
        public ConstraintModel[] constraints; 
    }
    
    public class FeatureModel { 
        public SBQQ__ProductFeature__c record; 
        public String instructionsText; 
        public Boolean containsUpgrades; 
    }
    
    public class OptionModel { 
        public SBQQ__ProductOption__c record; 
        public Map<String,String> externalConfigurationData; 
        public Boolean configurable; 
        public Boolean configurationRequired; 
        public Boolean quantityEditable; 
        public Boolean priceEditable; 
        public Decimal productQuantityScale; 
        public Boolean priorOptionExists; 
        public Set<Id> dependentIds; 
        public Map<String,Set<Id>> controllingGroups; 
        public Map<String,Set<Id>> exclusionGroups; 
        public String reconfigureDimensionWarning; 
        public Boolean hasDimension; 
        public Boolean isUpgrade; 
        public String dynamicOptionKey; 
    }
    
    public class ConfigurationModel { 
        public Id configuredProductId; 
        public Id optionId; 
        public SBQQ__ProductOption__c optionData; // Editable data about the option in question, such as quantity or discount 
        public SBQQ__ProductOption__c configurationData; 
        public SBQQ__ProductOption__c inheritedConfigurationData; 
        public ConfigurationModel[] optionConfigurations; 
        public Boolean configured; 
        public Boolean changedByProductActions; 
        public Boolean isDynamicOption; 
        public Boolean isUpgrade; 
        public Set<Id> disabledOptionIds; 
        public Set<Id> hiddenOptionIds; 
        public Decimal listPrice; 
        public Boolean priceEditable; 
        public String[] validationMessages; 
        public String dynamicOptionKey; 
    }
    
    public class ConfigAttributeModel { 
        public String name; 
        public String targetFieldName; 
        public Decimal displayOrder; 
        public String colmnOrder;
        public Boolean required;
        public Id featureId;
        public String position;
        public Boolean appliedImmediately;
        public Boolean applyToProductOptions;
        public Boolean autoSelect;
        public String[] shownValues;
        public String[] hiddenValues;
        public Boolean hidden;
        public String noSuchFieldName;
        public Id myId;
    }
    
    public class ConstraintModel { 
        public SBQQ__OptionConstraint__c record; 
        public Boolean priorOptionExists; 
    }*/
}