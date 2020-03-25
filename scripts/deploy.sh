#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the SwiftAWSLambdaRuntime open source project
##
## Copyright (c) 2017-2018 Apple Inc. and the SwiftAWSLambdaRuntime project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

lambda_name=SwiftSample
s3_bucket=swift-lambda-test
executable=$(swift package dump-package | sed -e 's|: null|: ""|g' | jq '.products[] | (select(.type.executable)) | .name' | sed -e 's|"||g')

set -eu

echo "-------------------------------------------------------------------------"
echo "preparing docker build image"
echo "-------------------------------------------------------------------------"
docker build . -t builder

echo "-------------------------------------------------------------------------"
echo "updating code"
echo "-------------------------------------------------------------------------"
swift package update

echo "-------------------------------------------------------------------------"
echo "building lambda executable"
echo "-------------------------------------------------------------------------"
docker run --rm -v `pwd`:/workspace -w /workspace builder bash -cl "swift build -c release -Xswiftc -g"
echo "done"

echo "-------------------------------------------------------------------------"
echo "packaging lambda"
echo "-------------------------------------------------------------------------"
docker run --rm -v `pwd`:/workspace -w /workspace builder bash -cl "./scripts/package.sh $executable"

echo "-------------------------------------------------------------------------"
echo "uploading to s3"
echo "-------------------------------------------------------------------------"

aws s3 cp .build/lambda/lambda.zip s3://$s3_bucket/
aws lambda update-function-code --function $lambda_name --s3-bucket $s3_bucket --s3-key lambda.zip
