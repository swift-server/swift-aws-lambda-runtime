# Getting Started Quickly

Learn how to create your first project in 3 minutes.

Follow these instructions to get a high-level overview of the steps to write, test, and deploy your first Lambda function written in Swift.

For a detailed step-by-step instruction, follow the tutorial instead.

<doc:/tutorials/table-of-content>

For the impatient, keep reading.

## High-level instructions

Follow these 6 steps to write, test, and deploy a Lambda function in Swift.

1. Create a Swift project for an executable target 

```sh
swift package init --type executable 
```

2. Add dependencies on `AWSLambdaRuntime` library 

```swift
// swift-tools-version:5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "YourProjetName",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .executable(name: "YourFunctionName", targets: ["YourFunctionName"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "1.0.0-alpha"),
    ],
    targets: [
        .executableTarget(
            name: "YourFunctionName",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
            ],
            path: "."
        ),
    ]
)
```

3. Write your function code.

> Be sure to rename the `main.swift` file to something else.

Extends the `SimpleLambdaHandler` protocol and implement `handle(_:context)`.


If your Lambda function is invoked by another AWS service, use the `AWSLambdaEvent` library at [https://github.com/swift-server/swift-aws-lambda-events](https://github.com/swift-server/swift-aws-lambda-events)

```swift
import AWSLambdaRuntime

struct Input: Codable {
    let number: Double
}

struct Number: Codable {
    let result: Double
}

@main
struct SquareNumberHandler: SimpleLambdaHandler {
    typealias Event = Input
    typealias Output = Number
    
    func handle(_ event: Input, context: LambdaContext) async throws -> Number {
        Number(result: event.number * event.number)
    }
}
```

4. Test your code locally 

```sh
export LOCAL_LAMBDA_SERVER_ENABLED=true

swift run 

# Switch to another Terminal tab

curl --header "Content-Type: application/json" \
     --request POST                            \
     --data '{"number": 3}'                    \
     http://localhost:7000/invoke

{"result":9}
```

5. Build and package your code for AWS Lambda 

AWS Lambda runtime runs on Amazon Linux. You must compile your code for Amazon Linux.

> Be sure to have [Docker](https://docs.docker.com/desktop/install/mac-install/) installed for this step.

```sh
swift package --disable-sandbox plugin archive

-------------------------------------------------------------------------
building "squarenumberlambda" in docker
-------------------------------------------------------------------------
updating "swift:amazonlinux2" docker image
  amazonlinux2: Pulling from library/swift
  Digest: sha256:5b0cbe56e35210fa90365ba3a4db9cd2b284a5b74d959fc1ee56a13e9c35b378
  Status: Image is up to date for swift:amazonlinux2
  docker.io/library/swift:amazonlinux2
building "SquareNumberLambda"
  Building for production...
...
-------------------------------------------------------------------------
archiving "SquareNumberLambda"
-------------------------------------------------------------------------
1 archive created
  * SquareNumberLambda at /Users/YourUserName/SquareNumberLambda/.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/SquareNumberLambda/SquareNumberLambda.zip


cp .build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/SquareNumberLambda/SquareNumberLambda.zip ~/Desktop
```

6. Deploy on AWS Lambda

> Be sure [to have an AWS Account](https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-creating.html) to follow these steps.

- Connect to the [AWS Console](https://console.aws.amazon.com)
- Navigate to Lambda 
- Create a function
- Select **Provide your own bootstrap on Amazon Linux 2** as **Runtime**
- Select an **Architecture** that matches the one of the machine where you build the code. Select **x86_64** when you build on Intel-based Macs or **arm64** for Apple Silicon-based Macs.
- Upload the ZIP create during step 5
- Select the **Test** tab, enter a test event such as `{"number":3}` and select **Test**

If the test succeeds, you will see the result: '{"result":9}'


Congratulations 🎉! You just wrote, test, build, and deployed a Lambda function written in Swift.
