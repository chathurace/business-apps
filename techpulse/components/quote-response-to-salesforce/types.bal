type QuoteResponse record {|
    string oppName;
    string accountName;
    ItemPrice[] itemPrices;
|};

type ItemPrice record {|
    string item;
    decimal quantity;
    decimal unitPrice;
    decimal discount = 0;
    decimal totalPrice;
|};

type AccountId record {|
    string Id;
|};

type OpportunityId record {|
    string Id;
|};

type OpportunityProduct record {|
    string Id?;
    string OpportunityId?;
    string Working_with_3rd_party__c?;
    string Product2Id?;
    decimal Quantity?;
    decimal Discount?;
    decimal UnitPrice?;
|};

type Opportunity record {|
    string Name?;
    string CurrencyIsoCode?;
    string LeadSource?;
    string AccountId?;
    string ForecastCategoryName?;
    string CloseDate?;
    string StageName?;
    string Confidence__c?;
    string Pricebook2Id?;
    string Working_with_3rd_party__c?;
|};