This PR shows proof-of-concept code to add a deployer plugin, in addition to the existing archiver plugin. The deployer plugin generates a SAM deployment descriptor and calls the SAM command line to deploy the lambda function and it's dependencies.

### Motivation:

The existing `archive` plugin generates a ZIP to be deployed on AWS. While it removes undifferentiated heavy lifting to compile and package Swift code into a Lambda function package, it does not help Swift developers to deploy the Lambda function to AWS, nor define how to invoke this function from other AWS services.  Deploying requires knowledge about AWS, and deployment tools such as the AWS CLI, the CDK, the SAM CLI, or the AWS console.

Furthermore, most developers will deploy a Lambda function together with some front end infrastructure allowing to invoke the Lambda function. Most common invocation methods are through an HTTP REST API (provided by API Gateway) or processing messages from queues (SQS).  This means that, in addition of the deployment of the lambda function itself, the Lambda function developer must create, configure, and link to the Lambda function an API Gateway or a SQS queue.

SAM is an open source  command line tool that solves this problem. It allows developers to describe the function runtime environment and the additional resources that will trigger the lambda function in a simple YAML file.  SAM CLI allows to validate the descriptor file and to deploy the infrastructure into the AWS cloud.

It also allows for local testing, by providing a Local Lambda runtime environment and a local API Gateway mock in a docker container.

The `deploy` plugin leverages SAM to create an end-to-end infrastructure and to deploy it on AWS.  It relies on  configuration provided by the Swift lambda function developer to know how to expose the Lambda function to the external world. Right now, it support a subset of HTTP API Gateway v2 and SQS queues.

The Lambda function developer describes the API gateway or SQS queue using the Swift programming language by writing a `Deploy.swift` file (similar to `Package.swift` used by SPM).  The plugin transform the `Deploy.swift` data structure into a SAM template. It then calls the SAM CLI to validate and to deploy the template.

### Why create a dependency on SAM ?

SAM is already broadly adopted, well maintained and documented. It does the job.  I think it is easier to ask Swift Lambda function developers to install SAM (it is just two `brew` commands) rather than having this project investing in its own mechanism to describe a deployment and to generate the CloudFormation or CDK code to deploy the Lambda function and its dependencies. In the future, we might imagine a multi-framework solution where the plugin could generate code for SAM, or CDK, or Serverless etc ... I am curious to get community feedback about this choice.

### Modifications:

I added two targets to `Package.swift` : 

- `AWSLambdaDeployer` is the plugin itself. I followed the same structure and code as the `archive` plugin (similar configuration and shell code). 

- `AWSLambdaDeploymentDescriptor` is a shared library that contains the data structures definition to describe and to generate a JSON SAM deployment file. It models SAM resources such as a Lambda functions and its event sources : HTTP API and SQS queue. It contains the logic to generate the SAM deployment descriptor, using minimum information provided by the Swift lambda function developer. At the moment it provides a very minimal subset of the supported SAM configuration. I am ready to invest more time to cover more resource types and more properties if this proposal is accepted.

I added a new Example project : `SAM`. It contains two Lambda functions, one invoked through HTTP API, and one invoked through SQS.  It also defines shared resources such as SQS Queue and a DynamoDB Table. It contains minimum code to describe the required HTTP API and SQS code and to allow `AWSLambdaDeploymentDescriptor` to generate the SAM deployment descriptor. 

### Result:

As a Swift function developer, here is the workflow to use the new `deploy` plugin.

1. I create a Lambda function as usual.  I use the Lambda Events library to write my code. Here is an example (nothing changed -  this is just to provide a starting point) : 

```swift
import AWSLambdaEvents
import AWSLambdaRuntime
import Foundation

@main
struct HttpApiLambda: SimpleLambdaHandler {
  typealias Event = APIGatewayV2Request
  typealias Output = APIGatewayV2Response

  init() {}
  init(context: LambdaInitializationContext) async throws {
    context.logger.info(
      "Log Level env var : \(ProcessInfo.processInfo.environment["LOG_LEVEL"] ?? "info" )")
  }

  func handle(_ event: Event, context: AWSLambdaRuntimeCore.LambdaContext) async throws -> Output {

    var header = HTTPHeaders()
    do {
      context.logger.debug("HTTP API Message received")

      header["content-type"] = "application/json"

      // echo the request in the response
      let data = try JSONEncoder().encode(event)
      let response = String(data: data, encoding: .utf8)

      return Output(statusCode: .accepted, headers: header, body: response)

    } catch {
      header["content-type"] = "text/plain"
      return Output(statusCode: .badRequest, headers: header, body: "\(error.localizedDescription)")
    }
  }
}
```

2. I create a `Deploy.swift` file to describe the SAM deployment descriptor.  Most of the deployment descriptor will be generated automatically from context, I just have to provide the specifics for my code.  In this example, I want the Lambda function to be invoked from an HTTP REST API. I want the code to be invoked on `GET` HTTP method for the `/test` path. I also want to position the LOG_LEVEL environment variable to `debug`.

I add a new `Deploy.swift` file at the top of my project. Here is a simple deployment file. A more complex one is provided in the commit.

```swift
import AWSLambdaDeploymentDescriptor

let _ = DeploymentDefinition(
    
    functions: [        
        .function(
            name: "HttpApiLambda",
            eventSources: [
                .httpApi(method: .GET, path: "/test"),
            ],
            environment: .variable(["LOG_LEVEL":"debug"]) //optional
        )
    ]
)
```

3. I invoke the archive plugin and the deploy plugin from the command line.

```bash

swift build 

# first create the zip file
swift package --disable-sandbox archive

# second deploy it with an HTTP API Gateway
swift package --disable-sandbox deploy
```

Similarly to the archiver plugin, the deployer plugin must escape the sandbox because the SAM CLI makes network calls to AWS API (IAM and CloudFormation) to validate and deploy the template.

4. (optionally) Swift lambda function developer may also use SAM to test the code locally.

```bash
sam local invoke -t sam.yaml -e test/apiv2.json HttpApiLambda
Invoking Provided (provided.al2)
Decompressing /Users/stormacq/Documents/amazon/code/lambda/swift/swift-aws-lambda-runtime/Examples/SAM/.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/HttpApiLambda/HttpApiLambda.zip
Skip pulling image and use local one: public.ecr.aws/sam/emulation-provided.al2:rapid-1.67.0-arm64.

Mounting /private/var/folders/14/nwpsn4b504gfp02_mrbyd2jr0000gr/T/tmpc6ajvoxv as /var/task:ro,delegated inside runtime container
START RequestId: 23cb7237-5c46-420a-b311-45ae9d4d19b7 Version: $LATEST
2022-12-23T14:28:34+0000 info Lambda : [AWSLambdaRuntimeCore] lambda runtime starting with LambdaConfiguration
  General(logLevel: debug))
  Lifecycle(id: 157597332736, maxTimes: 0, stopSignal: TERM)
  RuntimeEngine(ip: 127.0.0.1, port: 9001, requestTimeout: nil
2022-12-23T14:28:34+0000 debug Lambda : lifecycleId=157597332736 [AWSLambdaRuntimeCore] initializing lambda
2022-12-23T14:28:34+0000 debug Lambda : lifecycleIteration=0 [AWSLambdaRuntimeCore] lambda invocation sequence starting
2022-12-23T14:28:34+0000 debug Lambda : lifecycleIteration=0 [AWSLambdaRuntimeCore] requesting work from lambda runtime engine using /2018-06-01/runtime/invocation/next
2022-12-23T14:28:34+0000 debug Lambda : lifecycleIteration=0 [AWSLambdaRuntimeCore] sending invocation to lambda handler
2022-12-23T14:28:34+0000 debug Lambda : lifecycleIteration=0 [HttpApiLambda] HTTP API Message received
2022-12-23T14:28:34+0000 debug Lambda : lifecycleIteration=0 [AWSLambdaRuntimeCore] reporting results to lambda runtime engine using /2018-06-01/runtime/invocation/23cb7237-5c46-420a-b311-45ae9d4d19b7/response
2022-12-23T14:28:34+0000 debug Lambda : lifecycleIteration=0 [AWSLambdaRuntimeCore] lambda invocation sequence completed successfully
2022-12-23T14:28:34+0000 debug Lambda : lifecycleIteration=1 [AWSLambdaRuntimeCore] lambda invocation sequence starting
2022-12-23T14:28:34+0000 debug Lambda : lifecycleIteration=1 [AWSLambdaRuntimeCore] requesting work from lambda runtime engine using /2018-06-01/runtime/invocation/next
END RequestId: 23cb7237-5c46-420a-b311-45ae9d4d19b7
REPORT RequestId: 23cb7237-5c46-420a-b311-45ae9d4d19b7  Init Duration: 0.44 ms  Duration: 115.33 ms     Billed Duration: 116 ms Memory Size: 128 MB       Max Memory Used: 128 MB
{"headers":{"content-type":"application\/json"},"body":"{\"isBase64Encoded\":false,\"headers\":{\"x-forwarded-for\":\"90.103.90.59\",\"sec-fetch-site\":\"none\",\"x-amzn-trace-id\":\"Root=1-63a29de7-371407804cbdf89323be4902\",\"content-length\":\"0\",\"host\":\"x6v980zzkh.execute-api.eu-central-1.amazonaws.com\",\"x-forwarded-port\":\"443\",\"accept\":\"text\\\/html,application\\\/xhtml+xml,application\\\/xml;q=0.9,image\\\/avif,image\\\/webp,*\\\/*;q=0.8\",\"sec-fetch-user\":\"?1\",\"user-agent\":\"Mozilla\\\/5.0 (Macintosh; Intel Mac OS X 10.15; rv:108.0) Gecko\\\/20100101 Firefox\\\/108.0\",\"accept-language\":\"en-US,en;q=0.8,fr-FR;q=0.5,fr;q=0.3\",\"sec-fetch-dest\":\"document\",\"dnt\":\"1\",\"sec-fetch-mode\":\"navigate\",\"x-forwarded-proto\":\"https\",\"accept-encoding\":\"gzip, deflate, br\",\"upgrade-insecure-requests\":\"1\"},\"version\":\"2.0\",\"queryStringParameters\":{\"arg1\":\"value1\",\"arg2\":\"value2\"},\"routeKey\":\"$default\",\"requestContext\":{\"domainPrefix\":\"x6v980zzkh\",\"stage\":\"$default\",\"timeEpoch\":1671601639995,\"apiId\":\"x6v980zzkh\",\"http\":{\"protocol\":\"HTTP\\\/1.1\",\"sourceIp\":\"90.103.90.59\",\"method\":\"GET\",\"userAgent\":\"Mozilla\\\/5.0 (Macintosh; Intel Mac OS X 10.15; rv:108.0) Gecko\\\/20100101 Firefox\\\/108.0\",\"path\":\"\\\/test\"},\"time\":\"21\\\/Dec\\\/2022:05:47:19 +0000\",\"domainName\":\"x6v980zzkh.execute-api.eu-central-1.amazonaws.com\",\"requestId\":\"de2cRil5liAEM5Q=\",\"accountId\":\"486652066693\"},\"rawQueryString\":\"arg1=value1&arg2=value2\",\"rawPath\":\"\\\/test\"}","statusCode":202}% 
```

### What is missing ?

If this proposal is accepted, Swift Lambda function developers would need a much larger coverage of the SAM template format. I will add support for resources and properties. We can also look at generating the Swift data structures automatically from the AWS-provided SAM schema definition (in JSON)

Just like for the `archive` plugin, it would be great to have a more granular permission mechanism allowing to escape the plugin sandbox for selected network calls.

Happy to read your feedback and suggestions. Let's make the deployment of Swift Lambda functions easier for Swift developers.
