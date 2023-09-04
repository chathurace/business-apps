import ballerinax/kafka;
import ballerina/log;
import ballerinax/salesforce as sf;

configurable sf:ConnectionConfig salesforceConfig = ?;
configurable string salesforcePriceBookId = ?;

sf:Client salesforce = check new (salesforceConfig);
kafka:Consumer quoteResponseConsumer = check new(kafka:DEFAULT_URL, {
    offsetReset: kafka:OFFSET_RESET_EARLIEST, groupId: "quote-response-to-salesforce", topics: ["quote-responses"]});

public function main() returns error? {
    QuoteResponse[] quoteResponses = check quoteResponseConsumer->pollPayload(1);
    foreach QuoteResponse quote in quoteResponses {
        stream<AccountId, error?> accQuery = check salesforce->query(
            string `SELECT Id FROM Account WHERE Name = '${quote.accountName}'`);
        record {|AccountId value;|}? account = check accQuery.next();
        if account is () {
            continue;
        }
        stream<OpportunityId, error?> oppQuery = check salesforce->query(
            string `SELECT Id FROM Opportunity WHERE Name = '${quote.oppName}' AND AccountId = '${account.value.Id}'`);
        record {|OpportunityId value;|}? currentOpp = check oppQuery.next();
        if currentOpp is () {
            continue;
        }
        Opportunity opp = {
            StageName: "30 - Proposal/Price Quote"
        };
        check salesforce->update("Opportunity", currentOpp.value.Id, opp);

        stream<OpportunityProduct, error?> lineItems = check salesforce->query(
            string `SELECT Id, Product2Id, UnitPrice, Quantity FROM OpportunityLineItem WHERE OpportunityId = '${currentOpp.value.Id}'`);
        check from OpportunityProduct lineItem in lineItems do {
            foreach ItemPrice itemPrice in quote.itemPrices {
                if lineItem.Product2Id == itemPrice.item {
                    string? lineItemId = lineItem.Id;
                    if lineItemId !is () {
                        log:printInfo("Updating line item: " + lineItemId);
                        OpportunityProduct updatedLineItem = {
                            Quantity: itemPrice.quantity,
                            UnitPrice: itemPrice.unitPrice,
                            Discount: itemPrice.discount
                        };
                        check salesforce->update("OpportunityLineItem", lineItemId, updatedLineItem);
                    }
                }
            }
        };
    }
}
