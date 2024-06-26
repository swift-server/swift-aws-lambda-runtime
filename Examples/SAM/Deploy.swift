import AWSLambdaDeploymentDescriptor

// example of a shared resource
let sharedQueue = Queue(
  logicalName: "SharedQueue",
  physicalName: "swift-lambda-shared-queue")

// example of common environment variables
let sharedEnvironmentVariables = ["LOG_LEVEL": "debug"]

let validEfsArn =
  "arn:aws:elasticfilesystem:eu-central-1:012345678901:access-point/fsap-abcdef01234567890"

// the deployment descriptor
DeploymentDescriptor {

  // an optional description
  "Description of this deployment descriptor"

  // Create a lambda function exposed through a REST API
  Function(name: "HttpApiLambda") {

    // an optional description
    "Description of this function"

    EventSources {

      // example of a catch all api
      HttpApi()

      // example of an API for a specific HTTP verb and path
      // HttpApi(method: .GET, path: "/test")

    }

    EnvironmentVariables {
      [
        "NAME1": "VALUE1",
        "NAME2": "VALUE2",
      ]

      // shared environment variables declared upfront
      sharedEnvironmentVariables
    }
  }

  // Example Function modifiers:

  // .autoPublishAlias()
  // .ephemeralStorage(2048)
  // .eventInvoke(onSuccess: "arn:aws:sqs:eu-central-1:012345678901:lambda-test",
  //             onFailure: "arn:aws:lambda:eu-central-1:012345678901:lambda-test",
  //             maximumEventAgeInSeconds: 600,
  //             maximumRetryAttempts: 3)
  // .fileSystem(validEfsArn, mountPoint: "/mnt/path1")
  // .fileSystem(validEfsArn, mountPoint: "/mnt/path2")

  // Create a Lambda function exposed through an URL
  // you can invoke it with a signed request, for example
  // curl --aws-sigv4 "aws:amz:eu-central-1:lambda"        \
  //      --user $AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY \
  //      -H 'content-type: application/json'              \
  //      -d '{ "example": "test" }'                       \
  //      "$FUNCTION_URL?param1=value1&param2=value2"
  Function(name: "UrlLambda") {
    "A Lambda function that is directly exposed as an URL, with IAM authentication"
  }
  .urlConfig(authType: .iam)

  // Create a Lambda function triggered by messages on SQS
  Function(name: "SQSLambda", architecture: .arm64) {

    EventSources {

      // this will reference an existing queue by its Arn
      // Sqs("arn:aws:sqs:eu-central-1:012345678901:swift-lambda-shared-queue")

      // // this will create a new queue resource
      Sqs("swift-lambda-queue-name")

      // // this will create a new queue resource, with control over physical queue name
      // Sqs()
      //     .queue(logicalName: "LambdaQueueResource", physicalName: "swift-lambda-queue-resource")

      // // this references a shared queue resource created at the top of this deployment descriptor
      // // the queue resource will be created automatically, you do not need to add `sharedQueue` as a resource
      // Sqs(sharedQueue)
    }

    EnvironmentVariables {
      sharedEnvironmentVariables
    }
  }

  //
  // Additional resources
  //
  // Create a SQS queue
  Queue(
    logicalName: "TopLevelQueueResource",
    physicalName: "swift-lambda-top-level-queue")

  // Create a DynamoDB table
  Table(
    logicalName: "SwiftLambdaTable",
    physicalName: "swift-lambda-table",
    primaryKeyName: "id",
    primaryKeyType: "String")

  // example modifiers
  // .provisionedThroughput(readCapacityUnits: 10, writeCapacityUnits: 99)
}
