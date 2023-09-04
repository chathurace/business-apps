import ballerina/ftp;
import ballerina/log;
import ballerinax/edifact.d03a.finance.mQUOTES;
import ballerina/time;
import ballerina/file;
import ballerinax/kafka;

configurable ftp:ClientConfiguration ftpConfig = ?;
configurable string ftpQuoteResponsesPath = ?;

kafka:Consumer quoteResponseConsumer = check new (kafka:DEFAULT_URL, {
    offsetReset: kafka:OFFSET_RESET_EARLIEST, groupId: "quote-response-to-edi1", topics: ["quote-responses"]});
ftp:Client ftpClient = check new ftp:Client(ftpConfig);

public function main() returns error? {
    QuoteResponse[] quoteResponses = check quoteResponseConsumer->pollPayload(1);
    log:printDebug("Quotes received: " + quoteResponses.length().toString());
    foreach QuoteResponse quote in quoteResponses {
        log:printDebug("Processing quote response: " + quote.toJsonString());
        mQUOTES:EDI_QUOTES_Quote_message quoteMessage = check transformToQuoteMessage(quote);
        string quoteEdi = check mQUOTES:toEdiString(quoteMessage);
        check ftpClient->put(check file:joinPath(
            ftpQuoteResponsesPath, quote.accountName + "-" + quote.oppName + ".edi"), quoteEdi);    
    }
}

function transformToQuoteMessage(QuoteResponse quote) returns mQUOTES:EDI_QUOTES_Quote_message|error {
    mQUOTES:EDI_QUOTES_Quote_message quoteMessage = {
        BEGINNING_OF_MESSAGE: {
            DOCUMENT_MESSAGE_NAME: {Document_name_code: "220"},
            DOCUMENT_MESSAGE_IDENTIFICATION: {Document_identifier: "1180"},
            Message_function_code: "9"
        },
        SECTION_CONTROL: {Section_identification: "S"}
    };

    time:Utc utcNow = time:utcNow();
    time:Civil civilNow = time:utcToCivil(utcNow);
    mQUOTES:DATE_TIME_PERIOD_Type date = {
        DATE_TIME_PERIOD: {
            Date_or_time_or_period_function_code_qualifier: "137",
            Date_or_time_or_period_text: civilNow.year.toString() + civilNow.month.toString() + civilNow.day.toString(),
            Date_or_time_or_period_format_code: "102"}
    };
    quoteMessage.DATE_TIME_PERIOD.push(date);

    mQUOTES:Segment_group_1_GType oppName =
            {REFERENCE: {REFERENCE: {Reference_code_qualifier: "AES", Reference_identifier: quote.oppName}}};
    quoteMessage.Segment_group_1.push(oppName);

    mQUOTES:Segment_group_11_GType customer =
            {
        NAME_AND_ADDRESS: {
            Party_function_code_qualifier: "BY",
            PARTY_IDENTIFICATION_DETAILS: {
                Party_identifier: quote.accountName
            }
        }
    };
    quoteMessage.Segment_group_11.push(customer);

    foreach ItemPrice itemPrice in quote.itemPrices {
        mQUOTES:Segment_group_27_GType lineItem = {
            LINE_ITEM: {Line_item_identifier: itemPrice.item},
            QUANTITY: [{QUANTITY_DETAILS: {Quantity_type_code_qualifier: "21", Quantity: itemPrice.quantity.toString()}}],
            Segment_group_29: [
                {
                    MONETARY_AMOUNT: {
                        MONETARY_AMOUNT: {Monetary_amount_type_code_qualifier: "146", Monetary_amount: itemPrice.unitPrice.toString()}
                    }
                },
                {
                    MONETARY_AMOUNT: {
                        MONETARY_AMOUNT: {Monetary_amount_type_code_qualifier: "52", Monetary_amount: itemPrice.discount.toString()}
                    }
                },
                {
                    MONETARY_AMOUNT: {
                        MONETARY_AMOUNT: {
                            Monetary_amount_type_code_qualifier: "289",
                            Monetary_amount: (itemPrice.unitPrice * itemPrice.quantity - itemPrice.discount).toString()
                        }
                    }
                }
            ]
        };
        quoteMessage.Segment_group_27.push(lineItem);
    }
    return quoteMessage;
}
