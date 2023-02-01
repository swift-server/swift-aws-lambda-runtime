import AWSLambdaDeploymentDescriptor

// example of a shared resource
let sharedQueue : Resource = Resource.queue(logicalName: "SharedQueue",
                                            physicalName: "swift-lambda-shared-queue")

// example of common environment variables
let sharedEnvironementVariables = ["LOG_LEVEL":"debug"]

let _ = DeploymentDefinition(
    
    description: "Working SAM template for Swift Lambda function",
    
    functions: [
        
        .function(
            // the name of the function
            name: "HttpApiLambda",

            // the AWS Lambda architecture (defaults to current build platform)
            //architecture: .x64,
            
            // the event sources
            eventSources: [
                // example of a catch all API
//                .httpApi(),
                
                // example of an API for a specific path and specific http verb
                .httpApi(method: .GET, path: "/test"),
            ],
            
            // optional environment variables - one variable
            //environment: .variable("NAME","VALUE")
            
            // optional environment variables - multiple environment variables at once
            environment: .variable([sharedEnvironementVariables, ["NAME2":"VALUE2"]])
        ),
        
        .function(
            name: "SQSLambda",
            eventSources: [
                // this will reference an existing queue
//                .sqs(queue: "arn:aws:sqs:eu-central-1:012345678901:swift-lambda-shared-queue"),

                // this will create a new queue resource
                .sqs(queue: "swift-lambda-queue-name"),

                // this will create a new queue resource
//                .sqs(queue: .queue(logicalName: "LambdaQueueResource", physicalName: "swift-lambda-queue-resource"))

                // this will reference a queue resource created in this deployment descriptor
//                .sqs(queue: sharedQueue)
            ],
            environment: .variable(sharedEnvironementVariables)
        )
    ],
    
    // additional resources
    resources: [
        
        // create a SQS queue
        .queue(logicalName: "TopLevelQueueResource",
               physicalName: "swift-lambda-top-level-queue"),
        
        // create a DynamoDB table
        .table(logicalName: "SwiftLambdaTable",
               physicalName: "swift-lambda-table",
               primaryKeyName: "id",
               primaryKeyType: "String")
    ]
)
