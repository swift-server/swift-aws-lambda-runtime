> [!IMPORTANT] 
> The documentation included here refers to the Swift AWS Lambda Runtime v2 (code from the main branch). If you're developing for the runtime v1.x, check this [readme](https://github.com/swift-server/swift-aws-lambda-runtime/blob/v1/readme.md) instead.

> [!WARNING]
> The Swift AWS Runtime v2 is work in progress. We will add more documentation and code examples over time.

## Pre-requisites

- Ensure you have the Swift 6.x toolchain installed.  You can [install Swift toolchains](https://www.swift.org/install/macos/) from Swift.org

- When developing on macOs, be sure you use macOS 15 (Sequoia) or a more recent macOS version.

- To build and archive the package for AWS Lambda, you need to [install docker](https://docs.docker.com/desktop/install/mac-install/).

- To deploy the Lambda function and invoke it, you must have [an AWS account](https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-creating.html) and [install and configure the `aws` command line](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

## TL;DR

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

3. Edit `Sources/main.swift` file and replace the content with this code 

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

```bash
swift build
swift package archive --disable-sandbox
```

If there is no error, there is a ZIP file ready to deploy. 
The ZIP file is located at `.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/MyLambda/MyLambda.zip`

5. Deploy to AWS

There are multiple ways to deploy to AWS (SAM, Terraform, CDK, Console) that are covered later in this doc.
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

## Swift AWS Lambda Runtime

Many modern systems have client components like iOS, macOS or watchOS applications as well as server components that those clients interact with. Serverless functions are often the easiest and most efficient way for client application developers to extend their applications into the cloud.

Serverless functions are increasingly becoming a popular choice for running event-driven or otherwise ad-hoc compute tasks in the cloud. They power mission critical microservices and data intensive workloads. In many cases, serverless functions allow developers to more easily scale and control compute costs given their on-demand nature.

When using serverless functions, attention must be given to resource utilization as it directly impacts the costs of the system. This is where Swift shines! With its low memory footprint, deterministic performance, and quick start time, Swift is a fantastic match for the serverless functions architecture.

Combine this with Swift's developer friendliness, expressiveness, and emphasis on safety, and we have a solution that is great for developers at all skill levels, scalable, and cost effective.

Swift AWS Lambda Runtime was designed to make building Lambda functions in Swift simple and safe. The library is an implementation of the [AWS Lambda Runtime API](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-custom.html) and uses an embedded asynchronous HTTP Client based on [SwiftNIO](http://github.com/apple/swift-nio) that is fine-tuned for performance in the AWS Runtime context. The library provides a multi-tier API that allows building a range of Lambda functions: From quick and simple closures to complex, performance-sensitive event handlers.

## Design Principles

tbd + reference to the `v2-api.md` design doc.

## Tutorial 

link to [updated docc tutorial](https://swiftpackageindex.com/swift-server/swift-aws-lambda-runtime/1.0.0-alpha.3/tutorials/table-of-content)

## AWSLambdaRuntime API 

tbd 

### Lambda Streaming Response

tbd + link to docc

### Integration with Swift Service LifeCycle 

tbd + link to docc

### Background Tasks 

tbd + link to docc
