# APIGatewayREST

This sample extends the APIGateway into a simple REST endpoint to select articles.
This example uses a SAM template for deployment.

## Extended Deployment Instructions
If deploying this example as a brand new Lambda function your will want to configure the following:

1) You will need to create a user that is configured for deployment with Identity and Access Management.
    During deployment the user will need the following permissions:
    * AWS::Lambda::Alias   
    * AWS::Lambda::Permission 
    * AWS::IAM::Role  
    * AWS::Lambda::Version  
    * AWS::Lambda::Function  
    * AWS::ApiGatewayV2::Stage  
    * AWS::ApiGatewayV2::Api 

2) You will need access to the CloudFormation dashboard if you run into issues configuring the stack info.
