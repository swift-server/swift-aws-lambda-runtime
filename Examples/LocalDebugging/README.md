# Local Debugging Example

This sample project demonstrates how to write a simple Lambda function in Swift,
and how to use local debugging techniques that simulate how the Lambda function
would be invoked by the AWS Lambda Runtime engine.

The example includes an Xcode workspace with three modules:

1. [MyApp](MyApp) is a SwiftUI iOS application that calls the Lambda function.
2. [MyLambda](MyLambda) is a SwiftPM executable package for the Lambda function.
3. [Shared](Shared) is a SwiftPM library package used for shared code between the iOS application and the Lambda function,
such as the Request and Response model objects.

The local debugging experience is achieved by running the Lambda function in the context of the
debug-only local lambda engine simulator which starts a local HTTP server enabling the communication
between the iOS application and the Lambda function over HTTP.

To try out this example, open the workspace in Xcode and "run" the two targets,
using the relevant `MyLambda` and `MyApp` Xcode schemes.

Start with running the `MyLambda` target.
* Switch to the `MyLambda` scheme and select the "My Mac" destination
* Set the `LOCAL_LAMBDA_SERVER_ENABLED` environment variable to `true` by editing the `MyLambda` scheme Run/Arguments options.
* Hit `Run`
* Once it is up you should see a log message in the Xcode console saying
`LocalLambdaServer started and listening on 127.0.0.1:7000, receiving events on /invoke`
which means the local emulator is up and receiving traffic on port `7000` and expecting events on the `/invoke` endpoint.

Continue to run the `MyApp` target
* Switch to the `MyApp` scheme and select a simulator destination.
* Hit `Run`
* Once up, the application's UI should appear in the simulator allowing you
to interact with it.

Once both targets are running, set up breakpoints in the iOS application or Lambda function to observe the system behavior.
