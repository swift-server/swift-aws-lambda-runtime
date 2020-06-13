# Lambda Functions Examples

This sample project is a collection of Lambda functions that demonstrates
how to write a simple Lambda function in Swift, and how to package and deploy it
to the AWS Lambda platform.

The scripts are prepared to work from the `LambdaFunctions` folder.

```
git clone https://github.com/swift-server/swift-aws-lambda-runtime.git
cd swift-aws-lambda-runtime/Examples/LambdaFunctions
```

Note: The example scripts assume you have [jq](https://stedolan.github.io/jq/download/) command line tool installed.

## Deployment instructions using AWS CLI

Steps to deploy this sample to AWS Lambda using the AWS CLI:

1. Login to AWS Console and create an AWS Lambda with the following settings:
  * Runtime: Custom runtime
  * Handler: Can be any string, does not matter in this case

2. Build, package and deploy the Lambda

  ```
  ./scripts/deploy.sh
  ```

  Notes: 
  - This script assumes you have AWS CLI installed and credentials setup in `~/.aws/credentials`.
  - The default lambda function name is `SwiftSample`. You can specify a different one updating `lambda_name` in `deploy.sh`
  - Update `s3_bucket=swift-lambda-test` in `deploy.sh` before running (AWS S3 buckets require a unique global name)
  - Both lambda function and S3 bucket must exist before deploying for the first time.

### Deployment instructions using AWS SAM (Serverless Application Model)

AWS [Serverless Application Model](https://aws.amazon.com/serverless/sam/) (SAM) is an open-source framework for building serverless applications. This framework allows you to easily deploy other AWS resources and more complex deployment mechanisms such a CI pipelines.

***Note:*** Deploying using SAM will automatically create resources within your AWS account. Charges may apply for these resources.

To use SAM to deploy this sample to AWS:

1. Install the AWS CLI by following the [instructions](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html).

2. Install SAM CLI by following the [instructions](https://aws.amazon.com/serverless/sam/).

3. Build, package and deploy the Lambda

  ```
  ./scripts/sam-deploy.sh --guided
  ```

The script will ask you which sample Lambda you wish to deploy. It will then guide you through the SAM setup process.

  ```
        Setting default arguments for 'sam deploy'
	=========================================
	Stack Name [sam-app]: swift-aws-lambda-runtime-sample
	AWS Region [us-east-1]: <your-favourite-region>
	#Shows you resources changes to be deployed and require a 'Y' to initiate deploy
	Confirm changes before deploy [y/N]: Y
	#SAM needs permission to be able to create roles to connect to the resources in your template
	Allow SAM CLI IAM role creation [Y/n]: Y
	Save arguments to samconfig.toml [Y/n]: Y
  ```

If you said yes to confirm changes, SAM will ask you to accept changes to the infrastructure you are setting up. For more on this, see [Cloud Formation](https://aws.amazon.com/cloudformation/).

The `sam-deploy` script passes through any parameters to the SAM deploy command.

4. Subsequent deploys can just use the command minus the `guided` parameter:

  ```
  ./scripts/sam-deploy.sh
  ```

The script will ask you which sample Lambda you wish to deploy. If you are deploying a different sample lambda, the deploy process will pull down the previous Lambda.

SAM will still ask you to confirm changes if you said yes to that initially.

5. Testing

For the API Gateway sample:

The SAM template will provide an output labelled `LambdaApiGatewayEndpoint` which you can use to test the Lambda. For example:

  ```
  curl <<LambdaApiGatewayEndpoint>>
  ```  

***Warning:*** This SAM template is only intended as a sample and creates a publicly accessible HTTP endpoint.

For all other samples use the AWS Lambda console.

### Deployment instructions using Serverless Framework (serverless.com)

[Serverless framework](https://www.serverless.com/open-source/) (Serverless) is a provider agnostic, open-source framework for building serverless applications. This framework allows you to easily deploy other AWS resources and more complex deployment mechanisms such a CI pipelines. Serverless Framework offers solutions for not only deploying but also testing, monitoring, alerting, and security and is widely adopted by the industry and offers along the open-source version a paid one.

***Note:*** Deploying using Serverless will automatically create resources within your AWS account. Charges may apply for these resources.

To use Serverless to deploy this sample to AWS:

1. Install the AWS CLI by following the [instructions](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html).

2. Install Serverless by following the [instructions](https://www.serverless.com/framework/docs/getting-started/).
If you already have installed be sure you have the latest version.
The examples have been tested with the version 1.72.0.

```
Serverless --version
Framework Core: 1.72.0 (standalone)
Plugin: 3.6.13
SDK: 2.3.1
Components: 2.30.12
```

3. Build, package and deploy the Lambda

  ```
  ./scripts/serverless-deploy.sh
  ```

The script will ask you which sample Lambda you wish to deploy.

The `serverless-deploy.sh` script passes through any parameters to the Serverless deploy command.

4. Testing

For the APIGateway sample:

The Serverless template will provide an endpoint which you can use to test the Lambda. 

Outuput example:

```
...
...
Serverless: Stack update finished...
Service Information
service: apigateway-swift-aws
stage: dev
region: us-east-1
stack: apigateway-swift-aws-dev
resources: 12
api keys:
  None
endpoints:
  GET - https://r39lvhfng3.execute-api.us-east-1.amazonaws.com/api
functions:
  httpGet: apigateway-swift-aws-dev-httpGet
layers:
  None

Stack Outputs
HttpGetLambdaFunctionQualifiedArn: arn:aws:lambda:us-east-1:XXXXXXXXX:function:apigateway-swift-aws-dev-httpGet:1
ServerlessDeploymentBucketName: apigateway-swift-aws-dev-serverlessdeploymentbuck-ud51msgcrj1e
HttpApiUrl: https://r39lvhfng3.execute-api.us-east-1.amazonaws.com
```

For example:

  ```
  curl https://r39lvhfng3.execute-api.us-east-1.amazonaws.com/api
  ```  

***Warning:*** This Serverless template is only intended as a sample and creates a publicly accessible HTTP endpoint.

For all other samples use the AWS Lambda console.

4. Remove

 ```
  ./scripts/serverless-remove.sh
  ```

The script will ask you which sample Lambda you wish to remove from the previous depolyment.