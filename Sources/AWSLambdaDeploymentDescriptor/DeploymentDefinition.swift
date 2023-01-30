import Foundation

//
// The deployment definition
//
public struct DeploymentDefinition {
    
    public init(
        // the description of the SAM template
        description: String,
        
        // a list of AWS Lambda functions
        functions: [Function],
        
        // a list of additional AWS resources to create
        resources: [Resource])
    {
        
        var queueResources : [Resource] = []
        let functionResources = functions.compactMap { function in
            
            // compute the path for the lambda archive
            var lambdaPackage = ".build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/\(function.name)/\(function.name).zip"
            if let optIdx = CommandLine.arguments.firstIndex(of: "--archive-path") {
                if CommandLine.arguments.count >= optIdx + 1 {
                    let archiveArg = CommandLine.arguments[optIdx + 1]
                    lambdaPackage = "\(archiveArg)/\(function.name)/\(function.name).zip"
                    
                    // check the ZIP file exists
                    guard FileManager.default.fileExists(atPath: lambdaPackage) else {
                        fatalError("Lambda package does not exist at \(lambdaPackage)")
                    }
                }
            }
            
            // extract sqs resources to be created, if any
            queueResources += self.explicitQueueResources(function: function)
            
            return Resource.serverlessFunction(name: function.name,
                                               codeUri: lambdaPackage,
                                               eventSources: function.eventSources,
                                               environment: function.environment)
        }
        
        let deployment = SAMDeployment(description: description,
                                       resources:  functionResources + queueResources)
        
        //TODO: add default output section to return the URL of the API Gateway
        
        dumpPackageAtExit(deployment, to: 1) // 1 = stdout
    }
    
    // When SQS event source is specified, the Lambda function developer
    // might give a queue name, a queue Arn, or a queue resource.
    // When developer gives a queue Arn there is nothing to do here
    // When developer gives a queue name or a queue resource,
    // the event source eventually creates the queue resource and it returns a reference to the resource it has created
    // This function collects all queue resources created by SQS event sources or passed by Lambda function developer
    // to add them to the list of resources to synthetize
    private func explicitQueueResources(function: Function) -> [Resource] {
        
        return function.eventSources
        // first filter on event sources of type SQS where the `queue` property is defined (not nil)
            .filter{ lambdaEventSource in
                lambdaEventSource.type == .sqs && (lambdaEventSource.properties as? SQSEventProperties)?.queue != nil }
        // next extract the resource part of the sqsEventSource
            .compactMap {
                sqsEventSource in (sqsEventSource.properties as? SQSEventProperties)?.queue }
    }
}

// Intermediate structure to generate SAM Resources of type AWS::Serverless::Function
// this struct allows function developers to not provide the CodeUri property in Deploy.swift
// CodeUri is added when the SAM template is generated
// it is also a place to perform additional sanity checks

//TODO: should I move this to the Resource() struct ? Then I need a way to add CodeUri at a later stage
public struct Function {
    let name: String
    let eventSources: [EventSource]
    let environment: EnvironmentVariable
    public static func function(name : String,
                                eventSources: [EventSource],
                                environment: EnvironmentVariable = .none) -> Function {
        
        //TODO: report an error when multiple event sources of the same type are given
        //but print() is not sent to stdout when invoked from the plugin 🤷‍♂️
        
        // guardrail to avoid misformed SAM template
        if eventSources.filter({ source in source.type == .sqs }).count > 1  ||
            eventSources.filter({ source in source.type == .httpApi }).count > 1  {
            fatalError("WARNING - Function \(name) can only have one event source of each type")
        }
        
        return self.init(name: name,
                         eventSources: eventSources,
                         environment: environment)
    }
}

// inspired by
// https://github.com/apple/swift-package-manager/blob/main/Sources/PackageDescription/PackageDescription.swift#L479
private func manifestToJSON(_ deploymentDescriptor : DeploymentDescriptor) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let jsonData = try! encoder.encode(deploymentDescriptor)
    return String(data: jsonData, encoding: .utf8)!
}
private var dumpInfo: (deploymentDescriptor: DeploymentDescriptor, fileDesc: Int32)?
private func dumpPackageAtExit(_ deploymentDescriptor: DeploymentDescriptor, to fileDesc: Int32) {
    func dump() {
        guard let dumpInfo = dumpInfo else { return }
        guard let fd = fdopen(dumpInfo.fileDesc, "w") else { return }
        fputs(manifestToJSON(dumpInfo.deploymentDescriptor), fd)
        fclose(fd)
    }
    dumpInfo = (deploymentDescriptor, fileDesc)
    atexit(dump)
}    

