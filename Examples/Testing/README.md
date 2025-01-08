# Swift Testing Example

This is a simple example to show different testing strategies for your Swift Lambda functions.
For this example, we developed a simple Lambda function that returns the body of the API Gateway payload in lowercase, except for the first letter, which is in uppercase.

In this document, we describe four different testing strategies:
  * [Unit Testing your business logic](#unit-testing-your-business-logic)
  * [Integration testing the handler function](#integration-testing-the-handler-function)
  * [Local invocation using the Swift AWS Lambda Runtime](#local-invocation-using-the-swift-aws-lambda-runtime)
  * [Local invocation using the AWS SAM CLI](#local-invocation-using-the-aws-sam-cli)

> [!IMPORTANT]
> In this example, the API Gateway sends an event to your Lambda function as a JSON string. Your business payload is in the `body` section of the API Gateway event. It is base64-encoded. You can find an example of the API Gateway event in the `event.json` file. The API Gateway event format is documented in [Create AWS Lambda proxy integrations for HTTP APIs in API Gateway](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-integrations-lambda.html). 

To include a sample event in your test targets, you must add the `event.json` file from the `Tests` directory to the binary bundle. To do so, add a `resources` section in your `Package.swift` file:

```swift
        .testTarget(
            name: "LambdaFunctionTests",
            dependencies: ["APIGatewayLambda"],
            path: "Tests",
            resources: [
                .process("event.json")
            ]
        ) 
```

## Unit Testing your business logic

You can test the business logic of your Lambda function by writing unit tests for your business code used in the handler function, just like usual.

1. Create your Swift Test code in the `Tests` directory.

```swift
let valuesToTest: [(String, String)] = [
    ("hello world", "Hello world"), // happy path
    ("", ""), // Empty string
    ("a", "A"), // Single character
]

@Suite("Business Tests")
class BusinessTests {

    @Test("Uppercased First", arguments: valuesToTest)
    func uppercasedFirst(_ arg: (String,String)) {
        let input = arg.0
        let expectedOutput = arg.1
        #expect(input.uppercasedFirst() == expectedOutput)
    }
}
```

2. Add a test target to your `Package.swift` file.
```swift
        .testTarget(
            name: "BusinessTests",
            dependencies: ["APIGatewayLambda"],
            path: "Tests"
        )
```

3. run `swift test` to run the tests.

## Integration Testing the handler function

You can test the handler function by creating an input event, a mock Lambda context, and calling your Lambda handler function from your test.
Your Lambda handler function must be declared separatly from the `LambdaRuntime`. For example:

```swift
public struct MyHandler: Sendable {

    public func handler(event: APIGatewayV2Request, context: LambdaContext) async throws -> APIGatewayV2Response {
            context.logger.debug("HTTP API Message received")
            context.logger.trace("Event: \(event)")

            var header = HTTPHeaders()
            header["content-type"] = "application/json"

            if let payload = event.body {
                // call our business code to process the payload and return a response
                return APIGatewayV2Response(statusCode: .ok, headers: header, body: payload.uppercasedFirst())
            } else {
                return APIGatewayV2Response(statusCode: .badRequest)
            }
    }
}

let runtime = LambdaRuntime(body: MyHandler().handler)
try await runtime.run()
```

Then, the test looks like this:

```swift
@Suite("Handler Tests")
public struct HandlerTest {

    @Test("Invoke handler")
    public func invokeHandler() async throws {
        
        // read event.json file
        let testBundle = Bundle.module
        guard let eventURL = testBundle.url(forResource: "event", withExtension: "json") else {
            Issue.record("event.json not found in test bundle")
            return
        }
        let eventData = try Data(contentsOf: eventURL)

        // decode the event
        let apiGatewayRequest = try JSONDecoder().decode(APIGatewayV2Request.self, from: eventData)
        
        // create a mock LambdaContext 
        let lambdaContext = LambdaContext.__forTestsOnly(
            requestID: UUID().uuidString,
            traceID: UUID().uuidString,
            invokedFunctionARN: "arn:",
            timeout: .milliseconds(6000),
            logger: Logger(label: "fakeContext")
        )

        // call the handler with the event and context
        let response = try await MyHandler().handler(event: apiGatewayRequest, context: lambdaContext)

        // assert the response
        #expect(response.statusCode == .ok)
        #expect(response.body == "Hello world of swift lambda!")
    }
}
```

## Local invocation using the Swift AWS Lambda Runtime

You can test your Lambda function locally by invoking it with the Swift AWS Lambda Runtime.

You must pass an event to the Lambda function. You can use the `Tests/event.json` file for this purpose. The return value is a `APIGatewayV2Response` object in this example.

Just type `swift run` to run the Lambda function locally, this starts a local HTTP endpoint on localhost:7000.

```sh
LOG_LEVEL=trace swift run

# from another terminal
# the `-X POST` flag is implied when using `--data`. It is here for clarity only.
curl -X POST "http://127.0.0.1:7000/invoke" --data @Tests/event.json
```

This returns the following response:

```text
{"statusCode":200,"headers":{"content-type":"application\/json"},"body":"Hello world of swift lambda!"}
```

## Local invocation using the AWS SAM CLI

The AWS SAM CLI provides you with a local testing environment for your Lambda functions. It deploys and invokes your function locally in a Docker container designed to mimic the AWS Lambda environment.

You must pass an event to the Lambda function. You can use the `event.json` file for this purpose. The return value is a `APIGatewayV2Response` object in this example.

```sh
sam local invoke -e Tests/event.json

START RequestId: 3270171f-46d3-45f9-9bb6-3c2e5e9dc625 Version: $LATEST
2024-12-21T16:49:31+0000 debug LambdaRuntime : [AWSLambdaRuntimeCore] LambdaRuntime initialized
2024-12-21T16:49:31+0000 trace LambdaRuntime : lambda_ip=127.0.0.1 lambda_port=9001 [AWSLambdaRuntimeCore] Connection to control plane created
2024-12-21T16:49:31+0000 debug LambdaRuntime : [APIGatewayLambda] HTTP API Message received
2024-12-21T16:49:31+0000 trace LambdaRuntime : [APIGatewayLambda] Event: APIGatewayV2Request(version: "2.0", routeKey: "$default", rawPath: "/", rawQueryString: "", cookies: [], headers: ["x-forwarded-proto": "https", "host": "a5q74es3k2.execute-api.us-east-1.amazonaws.com", "content-length": "0", "x-forwarded-for": "81.0.0.43", "accept": "*/*", "x-amzn-trace-id": "Root=1-66fb03de-07533930192eaf5f540db0cb", "x-forwarded-port": "443", "user-agent": "curl/8.7.1"], queryStringParameters: [:], pathParameters: [:], context: AWSLambdaEvents.APIGatewayV2Request.Context(accountId: "012345678901", apiId: "a5q74es3k2", domainName: "a5q74es3k2.execute-api.us-east-1.amazonaws.com", domainPrefix: "a5q74es3k2", stage: "$default", requestId: "e72KxgsRoAMEMSA=", http: AWSLambdaEvents.APIGatewayV2Request.Context.HTTP(method: GET, path: "/", protocol: "HTTP/1.1", sourceIp: "81.0.0.43", userAgent: "curl/8.7.1"), authorizer: nil, authentication: nil, time: "30/Sep/2024:20:02:38 +0000", timeEpoch: 1727726558220), stageVariables: [:], body: Optional("aGVsbG8gd29ybGQgb2YgU1dJRlQgTEFNQkRBIQ=="), isBase64Encoded: false)
END RequestId: 5b71587a-39da-445e-855d-27a700e57efd
REPORT RequestId: 5b71587a-39da-445e-855d-27a700e57efd  Init Duration: 0.04 ms  Duration: 21.57 ms      Billed Duration: 22 ms     Memory Size: 512 MB     Max Memory Used: 512 MB

{"body": "Hello world of swift lambda!", "statusCode": 200, "headers": {"content-type": "application/json"}}
```
