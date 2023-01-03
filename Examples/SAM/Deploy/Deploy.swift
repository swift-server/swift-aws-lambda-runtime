import AWSLambdaDeploymentDescriptor
import Foundation

@main
public struct HttpApiLambdaDeployment: DeploymentDescriptor {

    // you have to include a main() method to generate the deployment descriptor 
    static func main() throws {
        HttpApiLambdaDeployment().run()
    }

    // optional, example of a shared resources between multiple Lambda functions 
    var queue : Resource 
    var table : Resource
    init() {
        self.queue = Resource.queue(logicalName: "SharedQueue", 
                                     physicalName: "swift-lambda-shared-queue")
        self.table = Resource.table(logicalName: "SwiftLambdaTable",
                                    physicalName: "swift-lambda-table",
                                    primaryKeyName: "id",
                                    primaryKeyType: "String")
    }

    // optional, define the event sources for each Lambda function
    public func eventSources(_ lambdaName: String) -> [EventSource] {

        if lambdaName == "HttpApiLambda" {
            // example of a Lambda function exposed through a REST API
            return [

                // this defines a catch all API (for all HTTP verbs and paths)
                .httpApi()

                // this defines a REST API for HTTP verb GET and path / test 
                // .httpApi(method: .GET, path: "/test"),
            ]

        } else if lambdaName == "SQSLambda" {

            // example of a Lambda function triggered when a message arrive on a queue 

            // this will create a new queue resource
            // return [.sqs(queue: "swift-lambda-test")]

            // this will reference an existing queue
            // return [.sqs(queue: "arn:aws:sqs:eu-central-1:012345678901:lambda-test")]

            // this will reference a queue resource created in this deployment descriptor 
            return [.sqs(queue: self.queue)]

        } else {
            fatalError("Unknown Lambda name : \(lambdaName)")
        }
    }

    // optional, define the environment variables for each Lambda function
    public func environmentVariables(_ lambdaName: String) -> EnvironmentVariable {

        // an environment variable for all functions
        var envVariables =  EnvironmentVariable([ "LOG_LEVEL": "debug" ])

        // variables specific for one Lambda function
        if (lambdaName == "HttpApiLambda") {
            // pass a reference to the shared queue and the DynamoDB table
            envVariables.append("QUEUE_URL", self.queue)
            envVariables.append("DYNAMO_TABLE", self.table)
        }

        return envVariables
    }

    // optional, additional resources to create on top of the Lambda functions and their direct dependencies
    // in this example, I create a DynamoDB Table
    public func addResource() -> [Resource] {
        return [self.table]
    }

}
