# Lambda Functions Examples

This sample project is a collection of Lambda functions that demonstrates
how to write a simple Lambda function in Swift, and how to package and deploy it
to the AWS Lambda platform.

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
