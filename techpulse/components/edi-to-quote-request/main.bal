import ballerinax/edifact.d03a.retail.mREQOTE;

import ballerina/io;
import ballerina/ftp;
import ballerinax/kafka;
import ballerina/file;

configurable ftp:ClientConfiguration ftpConfig = ?;
configurable string ftpNewQuotesPath = ?;
configurable string ftpProcessedQuotesPath = ?;

ftp:Client ftpClient = check new ftp:Client(ftpConfig);
kafka:Producer quoteRequestsProducer = check new(kafka:DEFAULT_URL);

public function main() returns error? {
    ftp:FileInfo[] quoteList = check ftpClient->list(ftpNewQuotesPath);
    foreach ftp:FileInfo quoteFile in quoteList {
        if !quoteFile.name.endsWith(".edi") {
            continue;
        }
        stream<byte[] & readonly, io:Error?> fileStream = check ftpClient->get(quoteFile.path);
        string quoteText = check streamToString(fileStream);
        mREQOTE:EDI_REQOTE_Request_for_quote_message quote = check mREQOTE:fromEdiString(quoteText);
        QuoteRequest quoteRequest = check transformQuoteRequest(quote);
        check quoteRequestsProducer->send({topic: "quote-requests", value: quoteRequest});
        
        check ftpClient->put(check file:joinPath(ftpProcessedQuotesPath, quoteFile.name), quoteText.toBytes());
        check ftpClient->delete(quoteFile.path);
    }
}

function transformQuoteRequest(mREQOTE:EDI_REQOTE_Request_for_quote_message quote) returns QuoteRequest|error {
    QuoteRequest quoteRequest = {accountName: "", oppName: ""};
    mREQOTE:Segment_group_1_GType[] segmentGroup1 = quote.Segment_group_1;
    foreach mREQOTE:Segment_group_1_GType ref in segmentGroup1 {
        if ref.REFERENCE.REFERENCE.Reference_code_qualifier == "AES" {
            string? oppId = ref.REFERENCE.REFERENCE.Reference_identifier;
            if oppId is () {
                return error("Opportunity ID is not given");
            }
            quoteRequest.oppName = oppId;
        }
    }
    mREQOTE:Segment_group_11_GType[] segmentGroup11 = quote.Segment_group_11;
    foreach mREQOTE:Segment_group_11_GType party in segmentGroup11 {
        if party.NAME_AND_ADDRESS.Party_function_code_qualifier == "BY" {
            string? prospectId = party.NAME_AND_ADDRESS?.PARTY_IDENTIFICATION_DETAILS?.Party_identifier;
            if prospectId is () {
                return error("Prospect identifier not available in quote.");
            }
            quoteRequest.accountName = prospectId;
        }
    }
    mREQOTE:Segment_group_27_GType[] items = quote.Segment_group_27;
    foreach mREQOTE:Segment_group_27_GType item in items {
        string? itemId = item.LINE_ITEM.Line_item_identifier;
        if itemId is () {
            return error("Item ID is not given");
        }
        ItemData itemData = {itemId};
        mREQOTE:QUANTITY_Type[] quantities = item.QUANTITY;
        foreach mREQOTE:QUANTITY_Type quantity in quantities {
            if quantity.QUANTITY_DETAILS.Quantity_type_code_qualifier == "21" {
                int|error amount = int:fromString(quantity.QUANTITY_DETAILS.Quantity);
                if amount is error {
                    return error("Quantity must be a valid number.");
                }
                itemData.quantity = amount;
                break;
            }
        }
        quoteRequest.itemData.push(itemData);
    }
    return quoteRequest;
}

function streamToString(stream<byte[] & readonly, io:Error?> inStream) returns string|error {
    byte[] content = [];
    check inStream.forEach(function (byte[] & readonly chunk) {
        content.push(...chunk);
    });
    return string:fromBytes(content);
}


