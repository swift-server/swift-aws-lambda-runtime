#!/bin/sh

# check if docker is installed
which docker > /dev/null
if [[ $? != 0 ]]; then
    echo "Docker is not installed.  Please install Docker and try again."
    exit 1
fi

# check if user has an access key and secret access key
echo "This script creates and deploys a Lambda function on your AWS Account.

You must have an AWS account and know an AWS access key, secret access key, and an optional session token.  These values are read from '~/.aws/credentials' or asked interactively.
"

read -p "Are you ready to create your first Lambda function in Swift? [y/n] " continue
if [[ continue != ^[Yy]$ ]]; then
  echo "OK, try again later when you feel ready"
  exit 1
fi

echo "⚡️ Create your Swift command line project"
swift package init --type executable --name MyLambda

echo "📦 Add the AWS Lambda Swift runtime to your project"
swift package add-dependency https://github.com/swift-server/swift-aws-lambda-runtime.git --branch main
swift package add-dependency https://github.com/swift-server/swift-aws-lambda-events.git --branch main
swift package add-target-dependency AWSLambdaRuntime MyLambda --package swift-aws-lambda-runtime
swift package add-target-dependency AWSLambdaEvents MyLambda --package swift-aws-lambda-events

echo "📝 Write the Swift code"
swift package lambda-init --allow-writing-to-package-directory 

echo "📦 Compile and package the function for deployment"
swift package archive --allow-network-connections docker

echo "🚀 Deploy to AWS Lambda"


