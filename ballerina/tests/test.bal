import ballerina/test;
import ballerina/oauth2;
// import ballerina/io;
import ballerina/os;
import ballerina/time;


configurable string clientId = ?;
configurable string clientSecret = ?;
configurable string refreshToken = ?; 

configurable boolean isServerLocal = os:getEnv("IsServerLocal") == "true";

OAuth2RefreshTokenGrantConfig auth = {
       clientId: clientId,
       clientSecret: clientSecret,
       refreshToken: refreshToken,
       credentialBearer: oauth2:POST_BODY_BEARER // this line should be added in to when you are going to create auth object.
   };

ConnectionConfig config = {auth : auth};
final string serviceURL = isServerLocal ? "localhost:8080" : "https://api.hubapi.com";
final Client hubspotClient = check new Client(config, serviceURL);

// Change this value and test
final int days = 40;


string testEmailId = "";

@test:Config
public function testCreateEmailEp() returns error? {
    PublicEmail|error response = check hubspotClient->/marketing/v3/emails.post({
        name: "Test email using API",
        subject: "Marketing Email using API!"
    });

    if response is PublicEmail {
        testEmailId = response.id;
    } else {
        test:assertFail("Failed to create new email");
    }
    
}


@test:Config{dependsOn: [testCreateEmailEp]}
public function testRetrieveEmailEp() returns error? {
    PublicEmail|error response = check hubspotClient->/marketing/v3/emails/[testEmailId];

    if response is PublicEmail {
        test:assertFalse(response.id != testEmailId, "Error: Incorrect email retrieved");
    } else {
        test:assertFail("Failed to retrieve email created during testing.");
    }
}


@test:Config{dependsOn: [testCreateEmailEp]}
public function testEmailsEp() returns error? {
    CollectionResponseWithTotalPublicEmailForwardPaging|error response = hubspotClient->/marketing/v3/emails();

    if response is CollectionResponseWithTotalPublicEmailForwardPaging {
        test:assertEquals(response.total, response.results.length());

        // Check that the newly created email above is included
        test:assertEquals(response.results[response.total - 1].id, testEmailId);

    } else {
        test:assertFail("Failed to get response from /marketing/v3/emails");
    }
}


@test:Config
isolated function testListEp() returns error? {
    AggregateEmailStatistics|error response = check hubspotClient->/marketing/v3/emails/statistics/list({}, 
    {
        startTimestamp: time:utcToString(time:utcAddSeconds(time:utcNow(), -86400*days)),
        endTimestamp: time:utcToString(time:utcNow())
    });

    if response is AggregateEmailStatistics {
        // Check that each part of the response response is not null
        test:assertTrue(response.aggregate !is ());
        test:assertTrue(response.campaignAggregations !is ());
        test:assertTrue(response.emails !is ());
    } else {
        test:assertFail("Failed to get response for endpoint /marketing/v3/emails/statistics/list");
    }
}


@test:Config
isolated function testHistogramEp() returns error? {
    CollectionResponseWithTotalEmailStatisticIntervalNoPaging|error response = check
    hubspotClient->/marketing/v3/emails/statistics/histogram({}, 
    {
        startTimestamp: time:utcToString(time:utcAddSeconds(time:utcNow(), -86400*days)),
        endTimestamp: time:utcToString(time:utcNow()),
        interval: "DAY"
    });

    if response is CollectionResponseWithTotalEmailStatisticIntervalNoPaging {
        // If there are no emails sent within the time span, the response will be of length 1
        // Else it should be of length equal to interval * timespan  + 1
        // Example: Length of results array should be 24*3 if the interval is HOUR and
        // duration between startTimestamp and endTimestamp is 3 days
        // In this case it should be equal to number of days + 1
        if (response.results.length() > 1) {
            test:assertEquals(response.results.length(), days + 1);
            test:assertEquals(response.total, days + 1);
        }
    } else {
        test:assertFail("Failed to get response from /marketing/v3/emails/statistics/histogram");
    }
}