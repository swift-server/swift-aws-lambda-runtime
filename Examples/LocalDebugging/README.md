# Local Debugging Example

This sample project demonstrates how to write a simple Lambda function in Swift,
and how to use local debugging techniques that emulate how the Lambda function
would be invoked by the AWS Lambda Runtime engine.

The example includes three modules:

1. [MyApp](MyApp) is a SwiftUI iOS application that calls the Lambda function.
2. [MyLambda](MyLambda) is a SwiftPM executable package for the Lambda function.
3. [Shared](Shared) is a SwiftPM library package used for shared code between the iOS application and the Lambda function,
such as the Request and Response model objects.

The local debugging experience is achieved by running the Lambda function in the context of the debug only `Lambda.withLocalServer`
function which starts a local emulator enabling the communication
between the iOS application and the Lambda function over HTTP.

To try out this example, open the workspace in Xcode and "run" the two targets,
using the relevant `MyLambda` and `MyApp` Xcode schemas.

Start with running the `MyLambda` target on the "My Mac" destination, once up you should see a log message in Xcode console saying
`LocalLambdaServer started and listening on 127.0.0.1:7000, receiving payloads on /invoke`
which means the local emulator is up and receiving traffic on port 7000 and expecting payloads on the `/invoke` endpoint.

Continue to run the `MyApp` target in a simulator destination. Once up, the application's UI should appear in the simulator allowing you
to interact with it.

Once both targets are running, set up breakpoints in the iOS application or Lambda function to observe the system behavior.
