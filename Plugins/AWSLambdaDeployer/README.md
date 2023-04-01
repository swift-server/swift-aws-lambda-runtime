This PR shows proof-of-concept code to add a deployer plugin, in addition to the existing archiver plugin. The deployer plugin generates a SAM deployment descriptor and calls the SAM command line to deploy the lambda function and it's dependencies.

## Motivation

The existing `archive` plugin generates a ZIP to be deployed on AWS. While it removes undifferentiated heavy lifting to compile and package Swift code into a Lambda function package, it does not help Swift developers to deploy the Lambda function to AWS, nor define how to invoke this function from other AWS services.  Deploying requires knowledge about AWS, and deployment tools such as the AWS CLI, the CDK, the SAM CLI, or the AWS console.

Furthermore, most developers will deploy a Lambda function together with some front end infrastructure allowing to invoke the Lambda function. Most common invocation methods are through an HTTP REST API (provided by API Gateway) or processing messages from queues (SQS).  This means that, in addition of the deployment of the lambda function itself, the Lambda function developer must create, configure, and link to the Lambda function an API Gateway or a SQS queue.

SAM is an open source  command line tool that allows Lambda function developers to easily express the function dependencies on other AWS services and deploy the function and its dependencies with an easy-to-use command lien tool. It allows developers to describe the function runtime environment and the additional resources that will trigger the lambda function in a simple YAML file. SAM CLI allows to validate the YAML file and to deploy the infrastructure into the AWS cloud.

It also allows for local testing, by providing a Local Lambda runtime environment and a local API Gateway mock in a docker container.

The `deploy` plugin leverages SAM to create an end-to-end infrastructure and to deploy it on AWS.  It relies on  configuration provided by the Swift lambda function developer to know how to expose the Lambda function to the external world. Right now, it supports a subset of HTTP API Gateway v2 and SQS queues.

The Lambda function developer describes the API gateway or SQS queue using a Swift-based domain specific language (DSL) by writing a `Deploy.swift` file.  The plugin transform the `Deploy.swift` data structure into a YAML SAM template. It then calls the SAM CLI to validate and to deploy the template.

## Modifications:

I added two targets to `Package.swift` : 

- `AWSLambdaDeployer` is the plugin itself. I followed the same structure and code as the `archive` plugin. Common code between the two plugins has been isolated in a shared `PluginUtils.swift` file. Because of [a limitation in the current Swift package systems for plugins](https://forums.swift.org/t/difficulty-sharing-code-between-swift-package-manager-plugins/61690/11), I symlinked the file from one plugin directory to the other.

- `AWSLambdaDeploymentDescriptor` is a shared library that contains the data structures definition to describe and to generate a YAML SAM deployment file. It models SAM resources such as a Lambda functions and its event sources : HTTP API and SQS queue. It contains the logic to generate the SAM deployment descriptor, using minimum information provided by the Swift lambda function developer. At the moment it provides a very minimal subset of the supported SAM configuration. I am ready to invest more time to cover more resource types and more properties if this proposal is accepted.

I also added a new example project : `SAM`. It contains two Lambda functions, one invoked through HTTP API, and one invoked through SQS.  It also defines shared resources such as SQS Queue and a DynamoDB Table. It provides a `Deploy.swift` example to describe the required HTTP API and SQS code and to allow `AWSLambdaDeploymentDescriptor` to generate the SAM deployment descriptor. The project also contains unit testing for the two Lambda functions.

## Result:

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

DeploymentDescriptor {
  // a mandatory description
  "Description of this deployment descriptor"

  // the lambda function
  Function(name: "HttpApiLambda") {
    EventSources {
      HttpApi(method: .GET, path: "/test") // example of an API for a specific HTTP verb and path
    }
    // optional environment variables
    EnvironmentVariables {
      [ "NAME1": "VALUE1" ]
    }
  }
}
```

3. I add a dependency in my project's `Package.swift`. On a `testTarget`, I add this dependency:

```swift
  // on the testTarget
  dependencies: [
      // other dependencies 
      .product(name: "AWSLambdaDeploymentDescriptor", package: "swift-aws-lambda-runtime")
  ]
```

I also might add this dependency on one of my Lambda functions `executableTarget`. In this case, I make sure it is added only when building on macOS.

```swift
  .product(name: "AWSLambdaDeploymentDescriptor", package: "swift-aws-lambda-runtime", condition: .when(platforms: [.macOS]))
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
sam local invoke -t template.yaml -e Tests/LambdaTests/data/apiv2.json HttpApiLambda 
```

## Command Line Options

The deployer plugin accepts multiple options on the command line.

```bash
swift package plugin deploy --help

OVERVIEW: A swift plugin to deploy your Lambda function on your AWS account.
          
REQUIREMENTS: To use this plugin, you must have an AWS account and have `sam` installed.
              You can install sam with the following command:
              (brew tap aws/tap && brew install aws-sam-cli)

USAGE: swift package --disable-sandbox deploy [--help] [--verbose]
                                              [--archive-path <archive_path>]
                                              [--configuration <configuration>]
                                              [--force] [--nodeploy] [--nolist]
                                              [--region <aws_region>]
                                              [--stack-name <stack-name>]

OPTIONS:
    --verbose       Produce verbose output for debugging.
    --archive-path <archive-path>
                    The path where the archive plugin created the ZIP archive.
                    Must be aligned with the value passed to archive --output-path plugin.
                    (default: .build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager)
    --configuration <configuration>
                    Build for a specific configuration.
                    Must be aligned with what was used to build and package.
                    Valid values: [ debug, release ] (default: debug)
    --force         Overwrites existing SAM deployment descriptor.
    --nodeploy      Generates the YAML deployment descriptor, but do not deploy.
    --nolist        Do not list endpoints.
    --stack-name <stack-name>
                    The name of the CloudFormation stack when deploying.
                    (default: the project name)
    --region        The AWS region to deploy to.
                    (default: the region of AWS CLI's default profile)
    --help          Show help information.
```

### Design Decisions

#### SAM

SAM is already broadly adopted, well maintained and documented. It does the job.  I think it is easier to ask Swift Lambda function developers to install SAM (it is just two `brew` commands) rather than having this project investing in its own mechanism to describe a deployment and to generate the CloudFormation or CDK code to deploy the Lambda function and its dependencies. In the future, we might imagine a multi-framework solution where the plugin could generate code for SAM, or CDK, or Serverless etc ... 

#### Deploy.swift DSL

Swift Lambda function developers must be able to describe the additional infrastructure services required to deploy their functions: a SQS queue, an HTTP API etc.

I assume the typical Lambda function developer knows the Swift programming language, but not the AWS-specific DSL (such as SAM or CloudFormation) required to describe and deploy the project dependencies. I chose to ask the Lambda function developer to describe its deployment with a Swift DSL in a top-level `Deploy.swift` file. The `deploy` plugin dynamically compiles this file to generate the SAM YAML deployment descriptor.

The source code to implement this approach is in the `AWSLambdaDeploymentDescriptor` library.

This is a strong design decision and [a one-way door](https://shit.management/one-way-and-two-way-door-decisions/). It engages the maintainer of the project on the long term to implement and maintain (close) feature parity between SAM DSL and the Swift `AWSLambdaDeploymentDescriptor` library and DSL.

One way to mitigate the maintenance work would be to generate the `AWSLambdaDeploymentDescriptor` library automatically, based on the [the SAM schema definition](https://github.com/aws/serverless-application-model/blob/develop/samtranslator/validator/sam_schema/schema.json). The core structs might be generated automatically and we would need to manually maintain only a couple of extensions providing syntactic sugar for Lambda function developers. This approach is similar to AWS SDKs code generation ([Soto](https://github.com/soto-project/soto-codegenerator) and the [AWS SDK for Swift](https://github.com/awslabs/aws-sdk-swift/tree/main/codegen)). This would require a significant one-time engineering effort however and I haven't had time to further explore this idea.

**Alternatives Considered** 

The first approach I used to implement `Deploy.swift` was pure programmatic.  Developers would have to define a data structure in the initializer of the `DeploymentDescriptor` struct. This approach was similar to current `Package.swift`. After initial review and discussions, @tomerd suggested to use a DSL approach instead as it is simpler to read and write, it requires less punctuation marks, etc.

An alternative would be to not use a DSL approach to describe the deployment at all (i.e. remove `Deploy.swift` and the `AWSLambdaDeploymentDescriptor` from this PR). In this scenario, the `deploy` plugin would generate a minimum SAM deployment template with default configuration for the current Lambda functions in the build target. The plugin would accept command-line arguments for basic pre-configuration of dependant AWS services, such as `--httpApi` or `--sqs <queue_name>` for example. The Swift Lambda function developer could leverage this SAM template to provide additional infrastructure or configuration elements as required. After having generated the initial SAM template, the `deploy` plugin will not overwrite the changes made by the developer.

This approach removes the need to maintain feature parity between the SAM DSL and the `AWSLambdaDeploymentDescriptor` library.

Please comment on this PR to share your feedback about the current design decisions and the proposed alternatives (or propose other alternatives :-) ) 

### What is missing

If this proposal is accepted in its current format, Swift Lambda function developers would need a much larger coverage of the SAM template format. I will add support for resources and properties. We can also look at generating the Swift data structures automatically from the AWS-provided SAM schema definition (in JSON)

### Future directions 

Here are a list of todo and thoughts for future implementations.

- Both for the `deploy` and the `archive` plugin, it would be great to have a more granular permission mechanism allowing to escape the SPM plugin sandbox for selected network calls. SPM 5.8 should make this happen.

- For HTTPApi, I believe the default SAM code and Lambda function examples must create Authenticated API by default. I believe our duty is to propose secured code by default and not encourage bad practices such as deploying open endpoints. But this approach will make the initial developer experience a bit more complex.

- This project should add sample code to demonstrate how to use the Soto SDK or the AWS SDK for Swift. I suspect most Swift Lambda function will leverage other AWS services.

- What about bootstrapping new projects? I would like to create a plugin or command line tool that would scaffold a new project, create the `Package.swift` file and the required project directory and files.  We could imagine a CLI or SPM plugin that ask the developer a couple of questions, such as how she wants to trigger the Lambda function and generate the corresponding code.

---

Happy to read your feedback and suggestions. Let's make the deployment of Swift Lambda functions easier for Swift developers.
