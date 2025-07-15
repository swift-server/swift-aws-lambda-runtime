# Streaming Codable Lambda function

This example demonstrates how to use the new `StreamingLambdaHandlerWithEvent` protocol to create Lambda functions that:

1. **Receive JSON input**: Automatically decode JSON events into Swift structs
2. **Stream responses**: Send data incrementally as it becomes available
3. **Execute background work**: Perform additional processing after the response is sent

The example uses the new streaming codable interface that combines the benefits of:
- Type-safe JSON input decoding (like regular `LambdaHandler`)
- Response streaming capabilities (like `StreamingLambdaHandler`)
- Background work execution after response completion

Streaming responses incurs a cost. For more information, see [AWS Lambda Pricing](https://aws.amazon.com/lambda/pricing/).

You can stream responses through [Lambda function URLs](https://docs.aws.amazon.com/lambda/latest/dg/urls-configuration.html), the AWS SDK, or using the Lambda [InvokeWithResponseStream](https://docs.aws.amazon.com/lambda/latest/dg/API_InvokeWithResponseStream.html) API.

## Code

The sample code creates a `StreamingFromEventHandler` struct that conforms to the `StreamingLambdaHandlerWithEvent` protocol provided by the Swift AWS Lambda Runtime.

The `handle(...)` method of this protocol receives incoming events as a decoded Swift struct (`StreamingRequest`) and returns the output through a `LambdaResponseStreamWriter`.

The Lambda function expects a JSON payload with the following structure:

```json
{
  "count": 5,
  "message": "Hello from streaming Lambda!",
  "delayMs": 1000
}
```

Where:
- `count`: Number of messages to stream (1-100)
- `message`: The message content to repeat
- `delayMs`: Optional delay between messages in milliseconds (defaults to 500ms)

The response is streamed through the `LambdaResponseStreamWriter`, which is passed as an argument in the `handle` function. The code calls the `write(_:)` function of the `LambdaResponseStreamWriter` with partial data repeatedly written before finally closing the response stream by calling `finish()`. Developers can also choose to return the entire output and not stream the response by calling `writeAndFinish(_:)`.

An error is thrown if `finish()` is called multiple times or if it is called after having called `writeAndFinish(_:)`.

The `handle(...)` method is marked as `mutating` to allow handlers to be implemented with a `struct`.

Once the struct is created and the `handle(...)` method is defined, the sample code creates a `LambdaRuntime` struct and initializes it with the handler just created. Then, the code calls `run()` to start the interaction with the AWS Lambda control plane.

Key features demonstrated:
- **JSON Input Decoding**: The function automatically parses the JSON input into a `StreamingRequest` struct
- **Input Validation**: Validates the count parameter and returns an error message if invalid
- **Progressive Streaming**: Sends messages one by one with configurable delays
- **Timestamped Output**: Each message includes an ISO8601 timestamp
- **Background Processing**: Performs cleanup and logging after the response is complete
- **Error Handling**: Gracefully handles invalid input with descriptive error messages

## Build & Package

To build & archive the package, type the following commands.

```bash
swift package archive --allow-network-connections docker
```

If there is no error, there is a ZIP file ready to deploy.
The ZIP file is located at `.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/StreamingFromEvent/StreamingFromEvent.zip`

## Test locally

You can test the function locally before deploying:

```bash
swift run &

# In another terminal, test with curl:
curl -v \
  --header "Content-Type: application/json" \
  --data '{"count": 3, "message": "Hello World!", "delayMs": 1000}' \
  http://127.0.0.1:7000/invoke
```

## Deploy with the AWS CLI

Here is how to deploy using the `aws` command line.

### Step 1: Create the function

```bash
# Replace with your AWS Account ID
AWS_ACCOUNT_ID=012345678901
aws lambda create-function \
--function-name StreamingFromEvent \
--zip-file fileb://.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/StreamingFromEvent/StreamingFromEvent.zip \
--runtime provided.al2 \
--handler provided \
--architectures arm64 \
--role arn:aws:iam::${AWS_ACCOUNT_ID}:role/lambda_basic_execution
```

The `--architectures` flag is only required when you build the binary on an Apple Silicon machine (Apple M1 or more recent). It defaults to `x64`.

Be sure to set `AWS_ACCOUNT_ID` with your actual AWS account ID (for example: 012345678901).

### Invoke your Lambda function

To invoke the Lambda function, use the AWS CLI:

```bash
aws lambda invoke \
  --function-name StreamingFromEvent \
  --payload $(echo '{"count": 5, "message": "Streaming from AWS!", "delayMs": 500}' | base64) \
  response.txt && cat response.txt
```

This should output the following result, with configurable delays between each message:

```
[2024-07-15T05:00:00Z] Message 1/3: Hello World!
[2024-07-15T05:00:01Z] Message 2/3: Hello World!
[2024-07-15T05:00:02Z] Message 3/3: Hello World!
✅ Successfully sent 3 messages
```

### Undeploy

When done testing, you can delete the Lambda function with this command.

```bash
aws lambda delete-function --function-name StreamingFromEvent
```
