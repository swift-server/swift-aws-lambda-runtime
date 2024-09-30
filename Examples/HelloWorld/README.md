# Hello World 

This is a simple example of an AWS Lambda function that takes a String as input parameter and returns a String as response.

## Code 

The code creates a `LambdaRuntime` struct. In it's simplest form, it takes a function as argument. The function is the Lambda handler that will be invoked when an event triggers the Lambda function.

The handler is `(event: String, context: LambdaContext) -> String`. The function takes two arguments:
- the event argument is a `String`. It is the parameter passed when invoking the function.
- the context argument is a `Lambda Context`. It is a description of the runtime context.

The function must return a String.

## Build & Package 

To build & archive the package, type the following commands.

```bash
swift build
swift package archive --disable-sandbox
```

If there is no error, there is a ZIP file ready to deploy. 
The ZIP file is located at `.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/MyLambda/MyLambda.zip`

## Deploy

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

## Invoke your Lambda function

To invoke the Lambda function, use this `aws` command line.

```bash
aws lambda invoke \
--function-name MyLambda \
--payload $(echo \"Seb\" | base64)  \
out.txt && cat out.txt && rm out.txt
```

Note that the payload is expected to be a valid JSON strings, hence the surroundings quotes (`"`).

This should print 

```
{
    "StatusCode": 200,
    "ExecutedVersion": "$LATEST"
}
"Hello Seb"
```
