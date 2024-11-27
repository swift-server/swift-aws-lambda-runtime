> [!IMPORTANT]
> The documentation included here refers to the Swift AWS Lambda Runtime v2 (code from the main branch). If you're developing for the runtime v1.x, check this [readme](https://github.com/swift-server/swift-aws-lambda-runtime/blob/v1/readme.md) instead.

> [!WARNING]
> The Swift AWS Runtime v2 is work in progress. We will add more documentation and code examples over time.

## Table of Content 

- [Table of Content](#table-of-content)
- [The Swift AWS Lambda Runtime](#the-swift-aws-lambda-runtime)
- [Pre-requisites](#pre-requisites)
- [Getting started](#getting-started)
- [Developing your Swift Lambda functions](#developing-your-swift-lambda-functions)
  * [Receive and respond with JSON objects](#receive-and-respond-with-json-objects)
  * [Lambda Streaming Response](#lambda-streaming-response)
  * [Integration with AWS Services](#integration-with-aws-services)
  * [Integration with Swift Service LifeCycle](#integration-with-swift-service-lifecycle)
  * [Use Lambda Background Tasks](#use-lambda-background-tasks)
- [Testing Locally](#testing-locally)
  * [Modifying the local endpoint](#modifying-the-local-endpoint)
- [Deploying your Swift Lambda functions](#deploying-your-swift-lambda-functions)
  * [Prerequisites](#prerequisites)
  * [Choosing the AWS Region where to deploy](#choosing-the-aws-region-where-to-deploy)
  * [The Lambda execution IAM role](#the-lambda-execution-iam-role)
  * [Deploy your Lambda function using the AWS Console](#deploy-your-lambda-function-using-the-aws-console)
  * [The AWS Command Line Interface (CLI)](#the-aws-command-line-interface-cli)
  * [AWS Serverless Application Model (SAM)](#aws-serverless-application-model-sam)
  * [AWS Cloud Development Kit (CDK)](#aws-cloud-development-kit-cdk)
  * [Third-party tools](#third-party-tools)
- [Swift AWS Lambda Runtime - Design Principles](#swift-aws-lambda-runtime---design-principles)
  * [Key Design Principles](#key-design-principles)
  * [New Capabilities](#new-capabilities)

## The Swift AWS Lambda Runtime

Many modern systems have client components like iOS, macOS or watchOS applications as well as server components that those clients interact with. Serverless functions are often the easiest and most efficient way for client application developers to extend their applications into the cloud.

Serverless functions are increasingly becoming a popular choice for running event-driven or otherwise ad-hoc compute tasks in the cloud. They power mission critical microservices and data intensive workloads. In many cases, serverless functions allow developers to more easily scale and control compute costs given their on-demand nature.

When using serverless functions, attention must be given to resource utilization as it directly impacts the costs of the system. This is where Swift shines! With its low memory footprint, deterministic performance, and quick start time, Swift is a fantastic match for the serverless functions architecture.

Combine this with Swift's developer friendliness, expressiveness, and emphasis on safety, and we have a solution that is great for developers at all skill levels, scalable, and cost effective.

Swift AWS Lambda Runtime was designed to make building Lambda functions in Swift simple and safe. The library is an implementation of the [AWS Lambda Runtime API](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-custom.html) and uses an embedded asynchronous HTTP Client based on [SwiftNIO](http://github.com/apple/swift-nio) that is fine-tuned for performance in the AWS Runtime context. The library provides a multi-tier API that allows building a range of Lambda functions: From quick and simple closures to complex, performance-sensitive event handlers.

## Pre-requisites

- Ensure you have the Swift 6.x toolchain installed.  You can [install Swift toolchains](https://www.swift.org/install/macos/) from Swift.org

- When developing on macOS, be sure you use macOS 15 (Sequoia) or a more recent macOS version.

- To build and archive your Lambda function, you need to [install docker](https://docs.docker.com/desktop/install/mac-install/).

- To deploy the Lambda function and invoke it, you must have [an AWS account](https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-creating.html) and [install and configure the `aws` command line](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

- Some examples are using [AWS SAM](https://aws.amazon.com/serverless/sam/). Install the [SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html) before deploying these examples.

## Getting started

To get started, read [the Swift AWS Lambda runtime v1 tutorial](https://swiftpackageindex.com/swift-server/swift-aws-lambda-runtime/1.0.0-alpha.3/tutorials/table-of-content). It provides developers with detailed step-by-step instructions to develop, build, and deploy a Lambda function.

Or, if you're impatient to start with runtime v2, try these six steps:

The `Examples/_MyFirstFunction` contains a script that goes through the steps described in this section.

If you are really impatient, just type:

```bash
cd Examples/_MyFirstFunction
./create_and_deploy_function.sh
```

Otherwise, continue reading.

1. Create a new Swift executable project

```bash
mkdir MyLambda && cd MyLambda
swift package init --type executable
```

2. Prepare your `Package.swift` file

    2.1 Add the Swift AWS Lambda Runtime as a dependency

    ```bash
    swift package add-dependency https://github.com/swift-server/swift-aws-lambda-runtime.git --branch main
    swift package add-target-dependency AWSLambdaRuntime MyLambda --package swift-aws-lambda-runtime
    ```

    2.2 (Optional - only on macOS) Add `platforms` after `name`

    ```
        platforms: [.macOS(.v15)],
    ```

    2.3 Your `Package.swift` file must look like this

    ```swift
    // swift-tools-version: 6.0

    import PackageDescription

    let package = Package(
        name: "MyLambda",
        platforms: [.macOS(.v15)],
        dependencies: [
            .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", branch: "main"),
        ],
        targets: [
            .executableTarget(
                name: "MyLambda",
                dependencies: [
                    .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                ]
                ),
        ]
    )
    ```

3. Scaffold a minimal Lambda function

The runtime comes with a plugin to generate the code of a simple AWS Lambda function:

```bash
swift package lambda-init --allow-writing-to-package-directory
```

Your `Sources/main.swift` file must look like this.

```swift
import AWSLambdaRuntime

// in this example we are receiving and responding with strings

let runtime = LambdaRuntime {
    (event: String, context: LambdaContext) in
        return String(event.reversed())
}

try await runtime.run()
```

4. Build & archive the package

The runtime comes with a plugin to compile on Amazon Linux and create a ZIP archive:

```bash
swift package archive --allow-network-connections docker
```

If there is no error, the ZIP archive is ready to deploy.
The ZIP file is located at `.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/MyLambda/MyLambda.zip`

5. Deploy to AWS

There are multiple ways to deploy to AWS ([SAM](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/what-is-sam.html), [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started), [AWS Cloud Development Kit (CDK)](https://docs.aws.amazon.com/cdk/v2/guide/getting_started.html), [AWS Console](https://docs.aws.amazon.com/lambda/latest/dg/getting-started.html)) that are covered later in this doc.

Here is how to deploy using the `aws` command line.

```bash
aws lambda create-function \
--function-name MyLambda \
--zip-file fileb://.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/MyLambda/MyLambda.zip \
--runtime provided.al2 \
--handler provided  \
--architectures arm64 \
--role arn:aws:iam::<YOUR_ACCOUNT_ID>:role/lambda_basic_execution
```

The `--architectures` flag is only required when you build the binary on an Apple Silicon machine (Apple M1 or more recent). It defaults to `x64`.

Be sure to replace <YOUR_ACCOUNT_ID> with your actual AWS account ID (for example: 012345678901).

6. Invoke your Lambda function

```bash
aws lambda invoke \
--function-name MyLambda \
--payload $(echo \"Hello World\" | base64)  \
out.txt && cat out.txt && rm out.txt
```

This should print

```
{
    "StatusCode": 200,
    "ExecutedVersion": "$LATEST"
}
"dlroW olleH"
```

## Developing your Swift Lambda functions

### Receive and respond with JSON objects

Typically, your Lambda functions will receive an input parameter expressed as JSON and will respond with some other JSON. The Swift AWS Lambda runtime automatically takes care of encoding and decoding JSON objects when your Lambda function handler accepts `Decodable` and returns `Encodable` conforming types.

Here is an example of a minimal function that accepts a JSON object as input and responds with another JSON object.

```swift
import AWSLambdaRuntime

// the data structure to represent the input parameter
struct HelloRequest: Decodable {
    let name: String
    let age: Int
}

// the data structure to represent the output response
struct HelloResponse: Encodable {
    let greetings: String
}

// the Lambda runtime
let runtime = LambdaRuntime {
    (event: HelloRequest, context: LambdaContext) in

    HelloResponse(
        greetings: "Hello \(event.name). You look \(event.age > 30 ? "younger" : "older") than your age."
    )
}

// start the loop
try await runtime.run()
```

You can learn how to deploy and invoke this function in [the Hello JSON example README file](Examples/HelloJSON/README.md).

### Lambda Streaming Response

You can configure your Lambda function to stream response payloads back to clients. Response streaming can benefit latency sensitive applications by improving time to first byte (TTFB) performance. This is because you can send partial responses back to the client as they become available. Additionally, you can use response streaming to build functions that return larger payloads. Response stream payloads have a soft limit of 20 MB as compared to the 6 MB limit for buffered responses. Streaming a response also means that your function doesn’t need to fit the entire response in memory. For very large responses, this can reduce the amount of memory you need to configure for your function.

Streaming responses incurs a cost. For more information, see [AWS Lambda Pricing](https://aws.amazon.com/lambda/pricing/).

You can stream responses through [Lambda function URLs](https://docs.aws.amazon.com/lambda/latest/dg/urls-configuration.html), the AWS SDK, or using the Lambda [InvokeWithResponseStream](https://docs.aws.amazon.com/lambda/latest/dg/API_InvokeWithResponseStream.html) API. In this example, we create an authenticated Lambda function URL.

Here is an example of a minimal function that streams 10 numbers with an interval of one second for each number.

```swift
import AWSLambdaRuntime
import NIOCore

struct SendNumbersWithPause: StreamingLambdaHandler {
    func handle(
        _ event: ByteBuffer,
        responseWriter: some LambdaResponseStreamWriter,
        context: LambdaContext
    ) async throws {
        for i in 1...10 {
            // Send partial data
            try await responseWriter.write(ByteBuffer(string: "\(i)\n"))
            // Perform some long asynchronous work
            try await Task.sleep(for: .milliseconds(1000))
        }
        // All data has been sent. Close off the response stream.
        try await responseWriter.finish()
    }
}

let runtime = LambdaRuntime.init(handler: SendNumbersWithPause())
try await runtime.run()
```

You can learn how to deploy and invoke this function in [the streaming example README file](Examples/Streaming/README.md).

### Integration with AWS Services

 Most Lambda functions are triggered by events originating in other AWS services such as `Amazon SNS`, `Amazon SQS` or `AWS APIGateway`.

 The [Swift AWS Lambda Events](http://github.com/swift-server/swift-aws-lambda-events) package includes an `AWSLambdaEvents` module that provides implementations for most common AWS event types further simplifying writing Lambda functions.

 Here is an example Lambda function invoked when the AWS APIGateway receives an HTTP request.

 ```swift
import AWSLambdaEvents
import AWSLambdaRuntime

let runtime = LambdaRuntime {
    (event: APIGatewayV2Request, context: LambdaContext) -> APIGatewayV2Response in

    APIGatewayV2Response(statusCode: .ok, body: "Hello World!")
}

try await runtime.run()
```

 You can learn how to deploy and invoke this function in [the API Gateway example README file](Examples/APIGateway/README.md).

### Integration with Swift Service LifeCycle

tbd + link to docc

### Use Lambda Background Tasks

Background tasks allow code to execute asynchronously after the main response has been returned, enabling additional processing without affecting response latency. This approach is ideal for scenarios like logging, data updates, or notifications that can be deferred. The code leverages Lambda's "Response Streaming" feature, which is effective for balancing real-time user responsiveness with the ability to perform extended tasks post-response. For more information about Lambda background tasks, see [this AWS blog post](https://aws.amazon.com/blogs/compute/running-code-after-returning-a-response-from-an-aws-lambda-function/).


Here is an example of a minimal function that waits 10 seconds after it returned a response but before the handler returns.
```swift
import AWSLambdaRuntime
import Foundation

struct BackgroundProcessingHandler: LambdaWithBackgroundProcessingHandler {
    struct Input: Decodable {
        let message: String
    }

    struct Greeting: Encodable {
        let echoedMessage: String
    }

    typealias Event = Input
    typealias Output = Greeting

    func handle(
        _ event: Event,
        outputWriter: some LambdaResponseWriter<Output>,
        context: LambdaContext
    ) async throws {
        // Return result to the Lambda control plane
        context.logger.debug("BackgroundProcessingHandler - message received")
        try await outputWriter.write(Greeting(echoedMessage: event.message))

        // Perform some background work, e.g:
        context.logger.debug("BackgroundProcessingHandler - response sent. Performing background tasks.")
        try await Task.sleep(for: .seconds(10))

        // Exit the function. All asynchronous work has been executed before exiting the scope of this function.
        // Follows structured concurrency principles.
        context.logger.debug("BackgroundProcessingHandler - Background tasks completed. Returning")
        return
    }
}

let adapter = LambdaCodableAdapter(handler: BackgroundProcessingHandler())
let runtime = LambdaRuntime.init(handler: adapter)
try await runtime.run()
```

You can learn how to deploy and invoke this function in [the background tasks example README file](Examples/BackgroundTasks/README.md).

## Testing Locally

Before deploying your code to AWS Lambda, you can test it locally by running the executable target on your local machine. It will look like this on CLI:

```sh
swift run
```

When not running inside a Lambda execution environment, it starts a local HTTP server listening on port 7000. You can invoke your local Lambda function by sending an HTTP POST request to `http://127.0.0.1:7000/invoke`.

The request must include the JSON payload expected as an `event` by your function. You can create a text file with the JSON payload documented by AWS or captured from a trace.  In this example, we used [the APIGatewayv2 JSON payload from the documentation](https://docs.aws.amazon.com/lambda/latest/dg/services-apigateway.html#apigateway-example-event), saved as `events/create-session.json` text file.

Then we use curl to invoke the local endpoint with the test JSON payload.

```sh
curl -v --header "Content-Type:\ application/json" --data @events/create-session.json http://127.0.0.1:7000/invoke
*   Trying 127.0.0.1:7000...
* Connected to 127.0.0.1 (127.0.0.1) port 7000
> POST /invoke HTTP/1.1
> Host: 127.0.0.1:7000
> User-Agent: curl/8.4.0
> Accept: */*
> Content-Type:\ application/json
> Content-Length: 1160
>
< HTTP/1.1 200 OK
< content-length: 247
<
* Connection #0 to host 127.0.0.1 left intact
{"statusCode":200,"isBase64Encoded":false,"body":"...","headers":{"Access-Control-Allow-Origin":"*","Content-Type":"application\/json; charset=utf-8","Access-Control-Allow-Headers":"*"}}
```
### Modifying the local endpoint

By default, when using the local Lambda server, it listens on the `/invoke` endpoint.

Some testing tools, such as the [AWS Lambda runtime interface emulator](https://docs.aws.amazon.com/lambda/latest/dg/images-test.html), require a different endpoint. In that case, you can use the `LOCAL_LAMBDA_SERVER_INVOCATION_ENDPOINT` environment variable to force the runtime to listen on a different endpoint.

Example:

```sh
LOCAL_LAMBDA_SERVER_INVOCATION_ENDPOINT=/2015-03-31/functions/function/invocations swift run
```

## Deploying your Swift Lambda functions

There are multiple ways to deploy your Swift code to AWS Lambda. The very first time, you'll probably use the AWS Console to create a new Lambda function and upload your code as a zip file. However, as you iterate on your code, you'll want to automate the deployment process.

To take full advantage of the cloud, we recommend using Infrastructure as Code (IaC) tools like the [AWS Serverless Application Model (SAM)](https://aws.amazon.com/serverless/sam/) or [AWS Cloud Development Kit (CDK)](https://aws.amazon.com/cdk/). These tools allow you to define your infrastructure and deployment process as code, which can be version-controlled and automated.

In this section, we show you how to deploy your Swift Lambda functions using different AWS Tools. Alternatively, you might also consider using popular third-party tools like [Serverless Framework](https://www.serverless.com/), [Terraform](https://www.terraform.io/), or [Pulumi](https://www.pulumi.com/) to deploy Lambda functions and create and manage AWS infrastructure.

### Prerequisites

1. Your AWS Account

   To deploy a Lambda function on AWS, you need an AWS account. If you don't have one yet, you can create a new account at [aws.amazon.com](https://signin.aws.amazon.com/signup?request_type=register). It takes a few minutes to register. A credit card is required.

   We do not recommend using the root credentials you entered at account creation time for day-to-day work. Instead, create an [Identity and Access Manager (IAM) user](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users.html) with the necessary permissions and use its credentials.
   
   Follow the steps in [Create an IAM User in your AWS account](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html).
   
   We suggest to attach the `AdministratorAccess` policy to the user for the initial setup. For production workloads, you should follow the principle of least privilege and grant only the permissions required for your users. The ['AdministratorAccess' gives the user permission](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_managed-vs-inline.html#aws-managed-policies) to manage all resources on the AWS account.

2. AWS Security Credentials

   [AWS Security Credentials](https://docs.aws.amazon.com/IAM/latest/UserGuide/security-creds.html) are required to access the AWS console, AWS APIs, or to let tools access your AWS account.
  
   AWS Security Credentials can be **long-term credentials** (for example, an Access Key ID and a Secret Access Key attached to your IAM user) or **temporary credentials** obtained via other AWS API, such as when accessing AWS through single sign-on (SSO) or when assuming an IAM role.

   To follow the steps in this guide, you need to know your AWS Access Key ID and Secret Access Key. If you don't have them, you can create them in the AWS Management Console. Follow the steps in [Creating access keys for an IAM user](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey).

   When you use SSO with your enterprise identity tools (such as Microsoft entra ID –formerly Active Directory–, Okta, and others) or when you write scripts or code assuming an IAM role, you receive temporary credentials. These credentials are valid for a limited time, have a limited scope, and are rotated automatically. You can use them in the same way as long-term credentials. In addtion to an AWS Access Key and Secret Access Key, temporary crednentials include a session token.

   Here is a typical set of temporary credentials (redacted for security).

   ```json
   {
     "Credentials": {
        "AccessKeyId": "ASIA...FFSD",
        "SecretAccessKey": "Xn...NL",
        "SessionToken": "IQ...pV",
        "Expiration": "2024-11-23T11:32:30+00:00"
     }
   }
   ```

### Choosing the AWS Region where to deploy

[AWS Global infrastructure](https://aws.amazon.com/about-aws/global-infrastructure/) spans over 34 geographic Regions (and continuously expanding). When you create a resource on AWS, such as a Lambda function, you have to select a geographic region where the resource will be created. The two main factors to consider to select a Region are the physical proximity with your users and geographical compliance. 

Physical proximity helps you reduce the network latency between the Lambda function and your customers. For example, when the majority of your users are located in South-East Asia, you might consider deploying in the Singapore, the Malaysia, or Jakarta Region.

Geographical compliance, also known as data residency compliance, involves following location-specific regulations about how and where data can be stored and processed.

### The Lambda execution IAM role

A Lambda execution role is an AWS Identity and Access Management (IAM) role that grants your Lambda function the necessary permissions to interact with other AWS services and resources. Think of it as a security passport that determines what your function is allowed to do within AWS. For example, if your Lambda function needs to read files from Amazon S3, write logs to Amazon CloudWatch, or access an Amazon DynamoDB table, the execution role must include the appropriate permissions for these actions.

When you create a Lambda function, you must specify an execution role. This role contains two main components: a trust policy that allows the Lambda service itself to assume the role, and permission policies that determine what AWS resources the function can access. By default, Lambda functions get basic permissions to write logs to CloudWatch Logs, but any additional permissions (like accessing S3 buckets or sending messages to SQS queues) must be explicitly added to the role's policies. Following the principle of least privilege, it's recommended to grant only the minimum permissions necessary for your function to operate, helping maintain the security of your serverless applications.

### Deploy your Lambda function with the AWS Console

Authenticate on the AWS console using your IAM username and password. On the top right side, select the AWS Region where you want to deploy, then navigate to the Lambda section.

![Console - Select AWS Region](/img/readme/console-10-regions.png)

#### Create the function 

Select **Create a function** to create a function.

![Console - Lambda dashboard when there is no function](/img/readme/console-20-dashboard.png)

Select **Author function from scratch**. Enter a **Function name** (`HelloWorld`) and select `Amazon Linux 2` as **Runtime**.
Select the architecture. When you compile your Swift code on a x84_64 machine, such as an Intel Mac, select `x86_64`. When you compile your Swift code on an Arm machine, such as the Apple Silicon M1 or more recent, select `arm64`.

Select **Create function**

![Console - create function](/img/readme/console-30-create-function.png)

On the right side, select **Upload from** and select **.zip file**.

![Console - select zip file](/img/readme/console-40-select-zip-file.png)

Select the zip file created with the `swift package archive --allow-network-conenctions docker` command.  This file is located in your project folder at `.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/MyLambda/MyLambda.zip`. The name of the ZIP file depends on the target name you entered in the `Package.swift` file.

Select **Save**

![Console - select zip file](/img/readme/console-50-upload-zip.png)

You're now ready to test your function.

#### Invoke the function 

Select the **Test** tab in the console and prepare a payload to send to your Lambda function. In this example, you've deployed the [HelloWorld](Exmaples.HelloWorld/README.md) example function. The function expects a `String` as input parameter and returns a `String`.

Select **Create new event**. Enter an **Event name**. Enter `"Swift on Lambda"` as **Event JSON**. Note that the payload must be a valid JSON document, hence we use surrounding double quotes (`"`).

Select **Test** on the upper right side of the screen.

![Console - prepare test event](/img/readme/console-60-prepare-test-event.png)

The response of the invocation and additional meta data appears in the green section of the page.

I can see the response from the Swift code: `Hello Swift on Lambda`.

The function consumed 109.60ms of execution time, out of this 83.72ms where spent to initialize this new runtime. This initialization time is known as Lambda cold start time.

> [!NOTE]
> Lambda cold start time refers to the initial delay that occurs when a Lambda function is invoked for the first time or after being idle for a while. Cold starts happen because AWS needs to provision and initialize a new container, load your code, and start your runtime environment (in this case, the Swift runtime). This delay is particularly noticeable for the first invocation, but subsequent invocations (known as "warm starts") are typically much faster because the container and runtime are already initialized and ready to process requests. Cold starts are an important consideration when architecting serverless applications, especially for latency-sensitive workloads.

![Console - view invocation result](/img/readme/console-70-view-invocation-response.png)

Select **Test** to invoke the function again with the same payload. 

Observe the results. No initialization time is reported because the Lambda execution environment was ready after the first invocation. The runtime duration of the second invocation is 1.12ms.

```text
REPORT RequestId: f789fbb6-10d9-4ba3-8a84-27aa283369a2	Duration: 1.12 ms	Billed Duration: 2 ms	Memory Size: 128 MB	Max Memory Used: 26 MB	
```

AWS lambda charges usage per number of invocations and the CPU time, rounded to the next millisecond. AWS Lambda offers a generous free-tier of 1 million invocation each month and 400,000 GB-seconds of compute time per month. See [Lambda pricing](https://aws.amazon.com/lambda/pricing/) for the details.

#### Delete the function

When you're finished with testing, you can delete the Lambda function and the IAM execution role that the console created automatically.

While you are on the `HelloWorld` function page in the AWS console, select **Actions**, then **Delete function** in the menu on the top-right part of the page.

![Console - delete function](/img/readme/console-80-delete-function.png)

Then, navigate to the IAM section of the AWS console. Select **Roles** on the right-side menu and search for `HelloWorld`. The console appended some random caracters to role name. The name you see on your console is different that the one on the screenshot.

Select the `HelloWorld-role-xxxx` role and select **Delete**. Confirm the deletion by entering the role name again, and select **Delete** on the confirmation box.

![Console - delete IAM role](/img/readme/console-80-delete-role.png)

### Deploy your Lambda function with the AWS Command Line Interface (CLI)

You can deploy your Lambda function using the AWS Command Line Interface (CLI). The CLI is a unified tool to manage your AWS services from the command line and automate your operations through scripts. The CLI is available for Windows, macOS, and Linux. Follow the [installation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and [configuration](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html) instructions in the AWS CLI User Guide.

#### Create the function 

To create a function, you must first create the function execution role and define the permission. Then, you create the function with the `create-function` command.

The command assumes you've already created the ZIP file with the `swift package archive --allow-network-connections docker` command. The name and the path of the ZIP file depends on the executable target name you entered in the `Package.swift` file.
 

```sh
# enter your AWS Account ID 
export AWS_ACCOUNT_ID=123456789012

# Allow the Lambda service to assume the execution role
cat <<EOF > assume-role-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

# Create the execution role
aws iam create-role \
--role-name lambda_basic_execution \
--assume-role-policy-document file://assume-role-policy.json

# create permissions to associate with the role
cat <<EOF > permissions.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        }
    ]
}
EOF

# Attach the permissions to the role
aws iam put-role-policy \
--role-name lambda_basic_execution \
--policy-name lambda_basic_execution_policy \
--policy-document file://permissions.json

# Create the Lambda function
aws lambda create-function \
--function-name MyLambda \
--zip-file fileb://.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/MyLambda/MyLambda.zip \
--runtime provided.al2 \
--handler provided  \
--architectures arm64 \
--role arn:aws:iam::${AWS_ACCOUNT_ID}:role/lambda_basic_execution
```

The `--architectures` flag is only required when you build the binary on an Apple Silicon machine (Apple M1 or more recent). It defaults to `x64`.

#### Invoke the function 

Use the `invoke-function` command to invoke the function. You can pass a well-formed JSON payload as input to the function. The payload must be encoded in base64. The CLI returns the status code and stores the response in a file.

```sh
# invoke the function
aws lambda invoke \
--function-name MyLambda \
--payload $(echo \"Swift Lambda function\" | base64)  \
out.txt

# show the response
cat out.txt

# delete the response file
rm out.txt
```

#### Delete the function

To cleanup, first delete the Lambda funtion, then delete the IAM role.

```sh
# delete the Lambda function
aws lambda delete-function --function-name MyLambda

# delete the IAM policy attached to the role
aws iam delete-role-policy --role-name lambda_basic_execution --policy-name lambda_basic_execution_policy

# delete the IAM role
aws iam delete-role --role-name lambda_basic_execution
```

### Deploy your Lambda function with AWS Serverless Application Model (SAM)

TODO

#### Create the function 

#### Invoke the function 

#### Delete the function

### Deploy your Lambda function with AWS Cloud Development Kit (CDK)

TODO

#### Create the function 

#### Invoke the function 

#### Delete the function

### Third-party tools

TODO

## Swift AWS Lambda Runtime - Design Principles

The [design document](Sources/AWSLambdaRuntimeCore/Documentation.docc/Proposals/0001-v2-api.md) details the v2 API proposal for the swift-aws-lambda-runtime library, which aims to enhance the developer experience for building serverless functions in Swift.

The proposal has been reviewed and [incorporated feedback from the community](https://forums.swift.org/t/aws-lambda-v2-api-proposal/73819). The full v2 API design document is available [in this repository](Sources/AWSLambdaRuntimeCore/Documentation.docc/Proposals/0001-v2-api.md).

### Key Design Principles

The v2 API prioritizes the following principles:

- Readability and Maintainability: Extensive use of `async`/`await` improves code clarity and simplifies maintenance.

- Developer Control: Developers own the `main()` function and have the flexibility to inject dependencies into the `LambdaRuntime`. This allows you to manage service lifecycles efficiently using [Swift Service Lifecycle](https://github.com/swift-server/swift-service-lifecycle) for structured concurrency.

- Simplified Codable Support: The `LambdaCodableAdapter` struct eliminates the need for verbose boilerplate code when encoding and decoding events and responses.

### New Capabilities

The v2 API introduces two new features:

[Response Streaming](https://aws.amazon.com/blogs/compute/introducing-aws-lambda-response-streaming/]): This functionality is ideal for handling large responses that need to be sent incrementally.  

[Background Work](https://aws.amazon.com/blogs/compute/running-code-after-returning-a-response-from-an-aws-lambda-function/): Schedule tasks to run after returning a response to the AWS Lambda control plane.

These new capabilities provide greater flexibility and control when building serverless functions in Swift with the swift-aws-lambda-runtime library.
