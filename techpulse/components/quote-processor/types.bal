type QuoteResponse record {|
    string oppName;
    string accountName;
    ItemPrice[] itemPrices;
|};

type ItemPrice record {|
    string item;
    int quantity;
    decimal unitPrice;
    decimal discount = 0;
    decimal totalPrice;
|};