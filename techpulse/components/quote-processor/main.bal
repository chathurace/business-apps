import ballerina/io;
import ballerinax/kafka;

public function main() returns error? {
    QuoteResponse quoteResponse = {
        accountName: "TechShop",
        oppName: "TSP_015",
        itemPrices: [
            {item: "01t6C000003idHmQAI", unitPrice: 880.0, quantity: 38, discount: 5.0, totalPrice: 31768.0},
            {item: "01t6C000003idHrQAI", unitPrice: 640.0, quantity: 50, discount: 0.0, totalPrice: 32000.0}
        ]
    };
    kafka:Producer quoteProducer = check new (kafka:DEFAULT_URL);
    check quoteProducer->send({topic: "quote-responses", value: quoteResponse});
    io:println("Quote response sent successfully");
}
