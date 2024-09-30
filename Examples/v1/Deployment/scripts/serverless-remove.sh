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

set -eu

DIR="$(cd "$(dirname "$0")" && pwd)"
source $DIR/config.sh

echo -e "\nremoving $executable"

echo "-------------------------------------------------------------------------"
echo "removing using Serverless"
echo "-------------------------------------------------------------------------"

serverless remove --config "./scripts/serverless/$executable-template.yml" --stage dev -v
