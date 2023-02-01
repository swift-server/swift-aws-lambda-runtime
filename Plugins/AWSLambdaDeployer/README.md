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

- `AWSLambdaDeployer` is the plugin itself. I followed the same structure and code as the `archive` plugin. Common code between the two plugins has been isolated in a shared `PluginUtils.swift` file. Because of [a limitation in the current Swift package systems for plugins](https://forums.swift.org/t/difficulty-sharing-code-between-swift-package-manager-plugins/61690/11), I symlinked the file from one plugin directory to the other.

- `AWSLambdaDeploymentDescriptor` is a shared library that contains the data structures definition to describe and to generate a JSON SAM deployment file. It models SAM resources such as a Lambda functions and its event sources : HTTP API and SQS queue. It contains the logic to generate the SAM deployment descriptor, using minimum information provided by the Swift lambda function developer. At the moment it provides a very minimal subset of the supported SAM configuration. I am ready to invest more time to cover more resource types and more properties if this proposal is accepted.

I added a new Example project : `SAM`. It contains two Lambda functions, one invoked through HTTP API, and one invoked through SQS.  It also defines shared resources such as SQS Queue and a DynamoDB Table. It provides a `Deploy.swift` example to describe the required HTTP API and SQS code and to allow `AWSLambdaDeploymentDescriptor` to generate the SAM deployment descriptor. The project also contains unit testing for the two Lambda functions.

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

I add the new `Deploy.swift` file at the top of my project. Here is a simple deployment file. A more complex one is provided in the `Examples/SAM` sample project.

```swift
import AWSLambdaDeploymentDescriptor

let _ = DeploymentDefinition(
    
    functions: [        
        .function(
            name: "HttpApiLambda",
            architecture: .arm64, // optional, defaults to current build platform
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

Similarly to the archiver plugin, the deployer plugin must escape the sandbox because the SAM CLI makes network calls to AWS API (IAM and CloudFormation) to validate and to deploy the template.

4. (optionally) Swift lambda function developer may also use SAM to test the code locally.

```bash
sam local invoke -t sam.json -e Tests/LambdaTests/data/apiv2.json HttpApiLambda 
```

### Command Line Options

The deployer plugin accepts multiple options on the command line.

```bash
swift package plugin deploy --help
OVERVIEW: A swift plugin to deploy your Lambda function on your AWS account.
          
REQUIREMENTS: To use this plugin, you must have an AWS account and have `sam` installed.
              You can install sam with the following command:
              (brew tap aws/tap && brew install aws-sam-cli)

USAGE: swift package --disable-sandbox deploy [--help] [--verbose] [--nodeploy] [--configuration <configuration>] [--archive-path <archive_path>] [--stack-name <stack-name>]

OPTIONS:
    --verbose       Produce verbose output for debugging.
    --nodeploy      Generates the JSON deployment descriptor, but do not deploy.
    --configuration <configuration>
                    Build for a specific configuration.
                    Must be aligned with what was used to build and package.
                    Valid values : [ debug, release ] (default: debug)
    --archive-path <archive-path>
                    The path where the archive plugin created the ZIP archive.
                    Must be aligned with the value passed to archive --output-path.
                    (default: .build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager)
    --stack-name <stack-name>
                    The name of the CloudFormation stack when deploying.
                    (default: the project name)
    --help          Show help information.
```


### What is missing ?

If this proposal is accepted, Swift Lambda function developers would need a much larger coverage of the SAM template format. I will add support for resources and properties. We can also look at generating the Swift data structures automatically from the AWS-provided SAM schema definition (in JSON)

Just like for the `archive` plugin, it would be great to have a more granular permission mechanism allowing to escape the plugin sandbox for selected network calls.

Happy to read your feedback and suggestions. Let's make the deployment of Swift Lambda functions easier for Swift developers.
