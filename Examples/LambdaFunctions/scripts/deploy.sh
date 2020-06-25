#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the SwiftAWSLambdaRuntime open source project
##
## Copyright (c) 2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

set -eu

DIR="$(cd "$(dirname "$0")" && pwd)"
source $DIR/config.sh

workspace="$DIR/../.."

echo -e "\ndeploying $executable"

$DIR/build-and-package.sh "$executable"

echo "-------------------------------------------------------------------------"
echo "uploading \"$executable\" lambda to AWS S3"
echo "-------------------------------------------------------------------------"

read -p "S3 bucket name to upload zip file (must exist in AWS S3): " s3_bucket
s3_bucket=${s3_bucket:-swift-lambda-test} # default for easy testing

aws s3 cp ".build/lambda/$executable/lambda.zip" "s3://$s3_bucket/"

echo "-------------------------------------------------------------------------"
echo "updating AWS Lambda to use \"$executable\""
echo "-------------------------------------------------------------------------"

read -p "Lambda Function name (must exist in AWS Lambda): " lambda_name
lambda_name=${lambda_name:-SwiftSample} # default for easy testing

aws lambda update-function-code --function "$lambda_name" --s3-bucket "$s3_bucket" --s3-key lambda.zip
