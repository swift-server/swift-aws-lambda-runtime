This directory contains example code for Lambda functions.

## Pre-requisites

- Ensure you have the Swift 6.x toolchain installed.  You can [install Swift toolchains](https://www.swift.org/install/macos/) from Swift.org

- When developing on macOS, be sure you use macOS 15 (Sequoia) or a more recent macOS version.

- To build and archive your Lambda functions, you need to [install docker](https://docs.docker.com/desktop/install/mac-install/).

- To deploy your Lambda functions and invoke them, you must have [an AWS account](https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-creating.html) and [install and configure the `aws` command line](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

- Some examples are using [AWS SAM](https://aws.amazon.com/serverless/sam/). Install the [SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html) before deploying these examples.

## Examples 

- **[API Gateway](APIGateway/README.md)**: an HTTPS REST API with [Amazon API Gateway](https://docs.aws.amazon.com/apigateway/latest/developerguide/welcome.html) and a Lambda function as backend (requires [AWS SAM](https://aws.amazon.com/serverless/sam/)).

- **[BackgroundTasks](BackgroundTasks/README.md)**: a Lambda function that continues to run background tasks after having sent the response (requires [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)).

- **[HelloJSON](HelloJSON/README.md)**: a Lambda function that accepts a JSON as input parameter and responds with a JSON output (requires [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)).

- **[HelloWorld](HelloWorld/README.md)**: a simple Lambda function (requires [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)).

- **[S3_AWSSDK](S3_AWSSDK/README.md)**: a Lambda function that uses the [AWS SDK for Swift](https://docs.aws.amazon.com/sdk-for-swift/latest/developer-guide/getting-started.html) to invoke an [Amazon S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html) API (requires [AWS SAM](https://aws.amazon.com/serverless/sam/)).

- **[S3_Soto](S3_Soto/README.md)**: a Lambda function that uses [Soto](https://github.com/soto-project/soto) to invoke an [Amazon S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html) API (requires [AWS SAM](https://aws.amazon.com/serverless/sam/)).

- **[Streaming]**: create a Lambda function exposed as an URL. The Lambda function streams its response over time. (requires [AWS SAM](https://aws.amazon.com/serverless/sam/)).

## AWS Credentials and Signature

This section is a short tutorial on the AWS Signature protocol and the AWS credentials.

**What is AWS SigV4?**

AWS SigV4, short for "Signature Version 4," is a protocol AWS uses to authenticate and secure requests. When you, as a developer, send a request to an AWS service, AWS SigV4 makes sure the request is verified and hasn’t been tampered with. This is done through a digital signature, which is created by combining your request details with your secret AWS credentials. This signature tells AWS that the request is genuine and is coming from a user who has the right permissions.

**How to Obtain AWS Access Keys and Session Tokens**

To start making authenticated requests with AWS SigV4, you’ll need three main pieces of information:

1. **Access Key ID**: This is a unique identifier for your AWS account, IAM (Identity and Access Management) user, or federated user.

2. **Secret Access Key**: This is a secret code that only you and AWS know. It works together with your access key ID to sign requests.

3. **Session Token (Optional)**: If you're using temporary security credentials, AWS will also provide a session token. This is usually required if you're using temporary access (e.g., through AWS STS, which provides short-lived, temporary credentials, or for federated users).

To obtain these keys, you need an AWS account:

1. **Sign up or Log in to AWS Console**: Go to the [AWS Management Console](https://aws.amazon.com/console/), log in, or create an AWS account if you don’t have one.

2. **Create IAM User**: In the console, go to IAM (Identity and Access Management) and create a new user. Ensure you set permissions that match what the user will need for your application (e.g., permissions to access specific AWS services, such as AWS Lambda).

3. **Generate Access Key and Secret Access Key**: In the IAM user settings, find the option to generate an "Access Key" and "Secret Access Key." Save these securely! You’ll need them to authenticate your requests.

4. **(Optional) Generate Temporary Security Credentials**: If you’re using temporary credentials (which are more secure for short-term access), use AWS Security Token Service (STS). You can call the `GetSessionToken` or `AssumeRole` API to generate temporary credentials, including a session token.

With these in hand, you can use AWS SigV4 to securely sign your requests and interact with AWS services from your Swift app.