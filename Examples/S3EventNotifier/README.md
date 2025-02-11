# S3 Event Notifier

This example demonstrates how to write a Lambda that is invoked by an event originating from Amazon S3, such as a new object being uploaded to a bucket.

## Code

In this example the lambda function receives an `S3Event` object defined in the `AWSLambdaEvents` library as input object. The `S3Event` object contains all the information about the S3 event that triggered the function, but what we are interested in is the bucket name and the object key, which are inside of a notification `Record`. The object contains an array of records, however since the lambda is triggered by a single event, we can safely assume that there is only one record in the array: the first one. Inside of this record, we can find the bucket name and the object key:

```swift
guard let s3NotificationRecord = event.records.first else {
    throw LambdaError.noNotificationRecord
}

let bucket = s3NotificationRecord.s3.bucket.name
let key = s3NotificationRecord.s3.object.key.replacingOccurrences(of: "+", with: " ")
```

The key is URL encoded, so we replace the `+` with a space.

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

Be sure to replace `<YOUR_ACCOUNT_ID>` with your actual AWS account ID (for example: 012345678901).

Besides deploying the lambda function you also need to create the S3 bucket and configure it to send events to the lambda function. You can do this using the following commands:

```bash
aws s3api create-bucket --bucket my-test-bucket --region eu-west-1 --create-bucket-configuration LocationConstraint=eu-west-1

aws lambda add-permission \
    --function-name ProcessS3Upload \
    --statement-id S3InvokeFunction \
    --action lambda:InvokeFunction \
    --principal s3.amazonaws.com \
    --source-arn arn:aws:s3:::my-test-bucket

aws s3api put-bucket-notification-configuration \
    --bucket my-test-bucket \
    --notification-configuration '{
        "LambdaFunctionConfigurations": [{
            "LambdaFunctionArn": "arn:aws:lambda:<REGION>:<YOUR_ACCOUNT_ID>:function:ProcessS3Upload",
            "Events": ["s3:ObjectCreated:*"]
        }]
    }'

aws s3 cp testfile.txt s3://my-test-bucket/
```

This will:
 - create a bucket named `my-test-bucket` in the `eu-west-1` region;
 - add a permission to the lambda function to be invoked by the bucket;
 - configure the bucket to send `s3:ObjectCreated:*` events to the lambda function named `ProcessS3Upload`;
 - upload a file named `testfile.txt` to the bucket.

Replace `<REGION>` with the region where you deployed the lambda function and `<YOUR_ACCOUNT_ID>` with your actual AWS account ID.
