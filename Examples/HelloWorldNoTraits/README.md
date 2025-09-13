# Hello World, with no traits

This is a simple example of an AWS Lambda function that takes a `String` as input parameter and returns a `String` as response.

This function disables all the default traits: the support for JSON from Foundation, for Swift Service Lifecycle, and for the local server for testing.

The main reasons of the existence of this example are 

1. to show you how to disable traits when using the Lambda Runtime Library 
2. to add an integration test to our continous integration pipeline to make sure the library compiles with no traits enabled.

For more details about this example, refer to the example in `Examples/HelloWorld`.