import AWSLambdaDeploymentDescriptor

// example of a shared resource
let sharedQueue = Queue(
  logicalName: "SharedQueue",
  physicalName: "swift-lambda-shared-queue")

// example of common environment variables
let sharedEnvironmentVariables = ["LOG_LEVEL": "debug"]

// the deployment descriptor
DeploymentDescriptor {

  // a mandatory description
  "Description of this deployment descriptor"

  // a lambda function
  Function(name: "HttpApiLambda", architecture: .x64) {

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

  // create a Lambda function and its depending resources
  Function(name: "SQSLambda") {

    EventSources {

      // this will reference an existing queue by its Arn
      // Sqs("arn:aws:sqs:eu-central-1:012345678901:swift-lambda-shared-queue")

      // // this will create a new queue resource
      Sqs("swift-lambda-queue-name")

      // // this will create a new queue resource, with control over physical queue name
      // Sqs()
      //     .queue(logicalName: "LambdaQueueResource", physicalName: "swift-lambda-queue-resource")

      // // this will reference a shared queue resource created in this deployment descriptor
      // Sqs(sharedQueue)
    }

    EnvironmentVariables {

      sharedEnvironmentVariables

    }
  }

  // shared resources declared upfront
  sharedQueue

  //
  // additional resources
  //
  // create a SAS queue
  Queue(
    logicalName: "TopLevelQueueResource",
    physicalName: "swift-lambda-top-level-queue")

  // create a DynamoDB table
  Table(
    logicalName: "SwiftLambdaTable",
    physicalName: "swift-lambda-table",
    primaryKeyName: "id",
    primaryKeyType: "String")

}
