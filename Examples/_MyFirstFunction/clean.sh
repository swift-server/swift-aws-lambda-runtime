#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the SwiftAWSLambdaRuntime open source project
##
## Copyright SwiftAWSLambdaRuntime project authors
## Copyright (c) Amazon.com, Inc. or its affiliates.
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

echo "This script deletes the Lambda function and the IAM role created in the previous step and deletes the project files."
read -r -p "Are you you sure you want to delete everything that was created? [y/n] " continue
if [[ ! $continue =~ ^[Yy]$ ]]; then
  echo "OK, try again later when you feel ready"
  exit 1
fi

echo "🚀 Deleting the Lambda function and the role"
aws lambda delete-function --function-name MyLambda
aws iam detach-role-policy            \
    --role-name lambda_basic_execution \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name lambda_basic_execution

echo "🚀 Deleting the project files"
rm -rf .build
rm -rf ./Sources
rm trust-policy.json
rm Package.swift Package.resolved

echo "🎉 Done! Your project is cleaned up and ready for a fresh start."