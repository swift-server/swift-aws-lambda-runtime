# Streaming Lambda function

You can configure your Lambda function to stream response payloads back to clients. Response streaming can benefit latency sensitive applications by improving time to first byte (TTFB) performance. This is because you can send partial responses back to the client as they become available. Additionally, you can use response streaming to build functions that return larger payloads. Response stream payloads have a soft limit of 20 MB as compared to the 6 MB limit for buffered responses. Streaming a response also means that your function doesn’t need to fit the entire response in memory. For very large responses, this can reduce the amount of memory you need to configure for your function.

Streaming responses incurs a cost. For more information, see [AWS Lambda Pricing](https://aws.amazon.com/lambda/pricing/).

You can stream responses through [Lambda function URLs](https://docs.aws.amazon.com/lambda/latest/dg/urls-configuration.html), the AWS SDK, or using the Lambda [InvokeWithResponseStream](https://docs.aws.amazon.com/lambda/latest/dg/API_InvokeWithResponseStream.html) API. In this example, we create an authenticated Lambda function URL.


## Code 

The sample code creates a `SendNumbersWithPause` struct that conforms to the `StreamingLambdaHandler` protocol provided by the Swift AWS Lambda Runtime.

The `handle(...)` method of this protocol receives incoming events as a Swift NIO `ByteBuffer` and returns the output as a `ByteBuffer`.

The response is streamed through the `LambdaResponseStreamWriter`, which is passed as an argument in the `handle` function. 

### Setting HTTP Status Code and Headers

Before streaming the response body, you can set the HTTP status code and headers using the `writeStatusAndHeaders(_:)` method:

```swift
try await responseWriter.writeStatusAndHeaders(
    StreamingLambdaStatusAndHeadersResponse(
        statusCode: 200,
        headers: [
            "Content-Type": "text/plain",
            "x-my-custom-header": "streaming-example"
        ],
        multiValueHeaders: [
            "Set-Cookie": ["session=abc123", "theme=dark"]
        ]
    )
)
```

The `StreamingLambdaStatusAndHeadersResponse` structure allows you to specify:
- **statusCode**: HTTP status code (e.g., 200, 404, 500)
- **headers**: Dictionary of single-value HTTP headers (optional)
- **multiValueHeaders**: Dictionary of multi-value HTTP headers like Set-Cookie (optional)

### Streaming the Response Body

After setting headers, you can stream the response body by calling the `write(_:)` function of the `LambdaResponseStreamWriter` with partial data repeatedly before finally closing the response stream by calling `finish()`. Developers can also choose to return the entire output and not stream the response by calling `writeAndFinish(_:)`.

```swift
// Stream data in chunks
for i in 1...10 {
    try await responseWriter.write(ByteBuffer(string: "Number: \(i)\n"))
    try await Task.sleep(for: .milliseconds(1000))
}

// Close the response stream
try await responseWriter.finish()
```

An error is thrown if `finish()` is called multiple times or if it is called after having called `writeAndFinish(_:)`.

### Example Usage Patterns

The example includes two handler implementations:

1. **SendNumbersWithPause**: Demonstrates basic streaming with headers, sending numbers with delays
2. **ConditionalStreamingHandler**: Shows how to handle different response scenarios, including error responses with appropriate status codes

The `handle(...)` method is marked as `mutating` to allow handlers to be implemented with a `struct`.

Once the struct is created and the `handle(...)` method is defined, the sample code creates a `LambdaRuntime` struct and initializes it with the handler just created. Then, the code calls `run()` to start the interaction with the AWS Lambda control plane.

## Build & Package 

To build & archive the package, type the following commands.

```bash
swift package archive --allow-network-connections docker
```

If there is no error, there is a ZIP file ready to deploy. 
The ZIP file is located at `.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/StreamingNumbers/StreamingNumbers.zip`

## Deploy with the AWS CLI

Here is how to deploy using the `aws` command line.

### Step 1: Create the function 

```bash
# Replace with your AWS Account ID
AWS_ACCOUNT_ID=012345678901
aws lambda create-function \
--function-name StreamingNumbers \
--zip-file fileb://.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/StreamingNumbers/StreamingNumbers.zip \
--runtime provided.al2 \
--handler provided  \
--architectures arm64 \
--role arn:aws:iam::${AWS_ACCOUNT_ID}:role/lambda_basic_execution \
--timeout 15
```

> [!IMPORTANT] 
> The timeout value must be bigger than the time it takes for your function to stream its output. Otherwise, the Lambda control plane will terminate the execution environment before your code has a chance to finish writing the stream. Here, the sample function stream responses during 10 seconds and we set the timeout for 15 seconds.

The `--architectures` flag is only required when you build the binary on an Apple Silicon machine (Apple M1 or more recent). It defaults to `x64`.

Be sure to set `AWS_ACCOUNT_ID` with your actual AWS account ID (for example: 012345678901).

### Step2: Give permission to invoke that function through an URL

Anyone with a valid signature from your AWS account will have permission to invoke the function through its URL.

```bash
aws lambda add-permission \
  --function-name StreamingNumbers \
  --action lambda:InvokeFunctionUrl \
  --principal ${AWS_ACCOUNT_ID} \
  --function-url-auth-type AWS_IAM \
  --statement-id allowURL
```  

### Step3: Create the URL 

This creates [a URL with IAM authentication](https://docs.aws.amazon.com/lambda/latest/dg/urls-auth.html). Only calls with a valid signature will be authorized.

```bash
aws lambda create-function-url-config \
  --function-name StreamingNumbers \
  --auth-type AWS_IAM \
  --invoke-mode RESPONSE_STREAM 
```
This calls return various information, including the URL to invoke your function.

```json
{
    "FunctionUrl": "https://ul3nf4dogmgyr7ffl5r5rs22640fwocc.lambda-url.us-east-1.on.aws/",
    "FunctionArn": "arn:aws:lambda:us-east-1:012345678901:function:StreamingNumbers",
    "AuthType": "AWS_IAM",
    "CreationTime": "2024-10-22T07:57:23.112599Z",
    "InvokeMode": "RESPONSE_STREAM"
}
```

### Invoke your Lambda function

To invoke the Lambda function, use `curl` with the AWS Sigv4 option to generate the signature.

Read the [AWS Credentials and Signature](../README.md/#AWS-Credentials-and-Signature) section for more details about the AWS Sigv4 protocol and how to obtain AWS credentials.

When you have the `aws` command line installed and configured, you will find the credentials in the `~/.aws/credentials` file.

```bash
URL=https://ul3nf4dogmgyr7ffl5r5rs22640fwocc.lambda-url.us-east-1.on.aws/
REGION=us-east-1
ACCESS_KEY=AK...
SECRET_KEY=...
AWS_SESSION_TOKEN=...

curl "$URL"                              \
     --user "${ACCESS_KEY}":"${SECRET_KEY}"   \
     --aws-sigv4 "aws:amz:${REGION}:lambda" \
     -H "x-amz-security-token: ${AWS_SESSION_TOKEN}" \
     --no-buffer
```

Note that there is no payload required for this example. 

This should output the following result, with a one-second delay between each numbers.

```
1
2
3
4
5
6
7
8
9
10
```

### Undeploy

When done testing, you can delete the Lambda function with this command.

```bash
aws lambda delete-function --function-name StreamingNumbers
```

## Deploy with AWS SAM 

Alternatively, you can use [AWS SAM](https://aws.amazon.com/serverless/sam/) to deploy the Lambda function.

**Prerequisites** : Install the [SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html)

### SAM Template

The template file is provided as part of the example in the `template.yaml` file. It defines a Lambda function based on the binary ZIP file. It creates the function url with IAM authentication and sets the function timeout to 15 seconds.

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: SAM Template for StreamingLambda Example

Resources:
  # Lambda function
  StreamingNumbers:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: .build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/StreamingNumbers/StreamingNumbers.zip
      Timeout: 15
      Handler: swift.bootstrap  # ignored by the Swift runtime
      Runtime: provided.al2
      MemorySize: 128
      Architectures:
        - arm64
      FunctionUrlConfig:
        AuthType: AWS_IAM
        InvokeMode: RESPONSE_STREAM

Outputs:
  # print Lambda function URL
  LambdaURL:
    Description: Lambda URL
    Value: !GetAtt StreamingNumbersUrl.FunctionUrl
```

### Deploy with SAM 

```bash
sam deploy \
--resolve-s3 \
--template-file template.yaml \
--stack-name StreamingNumbers \
--capabilities CAPABILITY_IAM 
```

The URL of the function is provided as part of the output.

```
CloudFormation outputs from deployed stack
-----------------------------------------------------------------------------------------------------------------------------
Outputs                                                                                                                                   
-----------------------------------------------------------------------------------------------------------------------------
Key                 LambdaURL                                                                                                             
Description         Lambda URL                                                                                                            
Value               https://gaudpin2zjqizfujfnqxstnv6u0czrfu.lambda-url.us-east-1.on.aws/                                                 
-----------------------------------------------------------------------------------------------------------------------------
```

Once the function is deployed, you can invoke it with `curl`, similarly to what you did when deploying with the AWS CLI.

```bash
curl "$URL"                              \
     --user "$ACCESS_KEY":"$SECRET_KEY"   \
     --aws-sigv4 "aws:amz:${REGION}:lambda" \
     -H "x-amz-security-token: $AWS_SESSION_TOKEN" \
     --no-buffer
```

### Undeploy with SAM 

When done testing, you can delete the infrastructure with this command.

```bash
sam delete 
```
