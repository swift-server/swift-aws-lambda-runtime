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

executable=MyLambda
lambda_name=SwiftSample
s3_bucket=swift-lambda-test

echo -e "\ndeploying $executable"

echo "-------------------------------------------------------------------------"
echo "preparing docker build image"
echo "-------------------------------------------------------------------------"
docker build . -t builder
echo "done"

echo "-------------------------------------------------------------------------"
echo "building \"$executable\" lambda"
echo "-------------------------------------------------------------------------"
docker run --rm -v `pwd`/../../..:/workspace -w /workspace/Examples/LocalDebugging/MyLambda builder \
       bash -cl "swift build --product $executable -c release"
echo "done"

echo "-------------------------------------------------------------------------"
echo "packaging \"$executable\" lambda"
echo "-------------------------------------------------------------------------"
docker run --rm -v `pwd`:/workspace -w /workspace builder \
       bash -cl "./scripts/package.sh $executable"
echo "done"

echo "-------------------------------------------------------------------------"
echo "uploading \"$executable\" lambda to s3"
echo "-------------------------------------------------------------------------"

aws s3 cp .build/lambda/$executable/lambda.zip s3://$s3_bucket/

echo "-------------------------------------------------------------------------"
echo "updating \"$lambda_name\" to latest \"$executable\""
echo "-------------------------------------------------------------------------"
aws lambda update-function-code --function $lambda_name --s3-bucket $s3_bucket --s3-key lambda.zip
