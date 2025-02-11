# S3 Event Notifier

This example demonstrates how to create a Lambda that notifies an API of an S3 event in a bucket.

## Code

In this example the lambda function receives an `S3Event` object from the `AWSLambdaEvents` library as input object instead of a `APIGatewayV2Request`. The `S3Event` object contains all the information about the S3 event that triggered the lambda, but what we are interested in is the bucket name and the object key, which are inside of a notification `Record`. The object contains an array of records, however since the lambda is triggered by a single event, we can safely assume that there is only one record in the array: the first one. Inside of this record, we can find the bucket name and the object key:

```swift
guard let s3NotificationRecord = event.records.first else {
    throw LambdaError.noNotificationRecord
}

let bucket = s3NotificationRecord.s3.bucket.name
let key = s3NotificationRecord.s3.object.key.replacingOccurrences(of: "+", with: " ")
```

The key is URL encoded, so we replace the `+` with a space.

Once the event is decoded, the lambda sends a POST request to an API endpoint with the bucket name and the object key as parameters. The API URL is set as an environment variable.

## Build & Package 

To build & archive the package you can use the following commands:

```bash
swift build
swift package archive --allow-network-connections docker
```

If there are no errors, a ZIP file should be ready to deploy, located at `.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/S3EventNotifier/S3EventNotifier.zip`.

## Deploy

To deploy the Lambda function, you can use the `aws` command line:

```bash
aws lambda create-function \
--function-name S3EventNotifier \
--zip-file fileb://.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/S3EventNotifier/S3EventNotifier.zip \
--runtime provided.al2 \
--handler provided  \
--architectures arm64 \
--role arn:aws:iam::<YOUR_ACCOUNT_ID>:role/lambda_basic_execution
```

The `--architectures` flag is only required when you build the binary on an Apple Silicon machine (Apple M1 or more recent). It defaults to `x64`.

Be sure to replace <YOUR_ACCOUNT_ID> with your actual AWS account ID (for example: 012345678901).

> [!WARNING]
> You will have to set up an S3 bucket and configure it to send events to the lambda function. This is not covered in this example.
