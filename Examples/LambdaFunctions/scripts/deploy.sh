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

# Lambda Function name (must exist in AWS Lambda)
lambda_name=SwiftSample

# S3 bucket name to upload zip file (must exist in AWS S3)
s3_bucket=swift-lambda-test



executables=( $(swift package dump-package | sed -e 's|: null|: ""|g' | jq '.products[] | (select(.type.executable)) | .name' | sed -e 's|"||g') )

if [[ ${#executables[@]} = 0 ]]; then
    echo "no executables found"
    exit 1
elif [[ ${#executables[@]} = 1 ]]; then
    executable=${executables[0]}
elif [[ ${#executables[@]} > 1 ]]; then
    echo "multiple executables found:"
    for executable in ${executables[@]}; do
      echo "  * $executable"
    done
    echo ""
    read -p "select which executables to deploy: " executable
fi

echo -e "\ndeploying $executable"

echo "-------------------------------------------------------------------------"
echo "preparing docker build image"
echo "-------------------------------------------------------------------------"
docker build . -t builder

echo "-------------------------------------------------------------------------"
echo "building \"$executable\" lambda"
echo "-------------------------------------------------------------------------"
docker run --rm -v `pwd`/../..:/workspace -w /workspace builder \
       bash -cl "cd Examples/LambdaFunctions && \
                 swift build --product $executable -c release -Xswiftc -g"
echo "done"

echo "-------------------------------------------------------------------------"
echo "packaging \"$executable\" lambda"
echo "-------------------------------------------------------------------------"
docker run --rm -v `pwd`:/workspace -w /workspace builder bash -cl "./scripts/package.sh $executable"

echo "-------------------------------------------------------------------------"
echo "uploading \"$executable\" lambda to s3"
echo "-------------------------------------------------------------------------"

aws s3 cp .build/lambda/$executable/lambda.zip s3://$s3_bucket/

echo "-------------------------------------------------------------------------"
echo "updating \"$lambda_name\" to latest \"$executable\""
echo "-------------------------------------------------------------------------"
aws lambda update-function-code --function $lambda_name --s3-bucket $s3_bucket --s3-key lambda.zip
