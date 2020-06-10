# APIGatewayEndpoint

This sample extends the APIGateway into a simple dynamic API endpoint to select articles.
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


## Current Implementation

Select All Articles:
```text
https://baseURL/articles
```

Select only one article:
```text
https://baseURL/articles?aid=1
```

In the future I would like to turn this into a true REST endpoint with `/articles/{aid}` but there seem to be some issues with routing that need to be addressed.
