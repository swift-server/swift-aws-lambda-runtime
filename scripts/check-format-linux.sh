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
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift.org open source project
##
## Copyright (c) 2020 Apple Inc. and the Swift project authors
## Licensed under Apache License v2.0 with Runtime Library Exception
##
## See https://swift.org/LICENSE.txt for license information
## See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
##
##===----------------------------------------------------------------------===##

set +x
set -euo pipefail

SWIFT_IMAGE=swift:latest
CHECK_FORMAT_SCRIPT=https://raw.githubusercontent.com/swiftlang/github-workflows/refs/heads/main/.github/workflows/scripts/check-swift-format.sh 

echo "Downloading check-swift-format.sh"
curl -s ${CHECK_FORMAT_SCRIPT} > format.sh && chmod u+x format.sh 

echo "Running check-swift-format.sh"
/usr/local/bin/docker run  --rm  -v "$(pwd):/workspace" -w /workspace ${SWIFT_IMAGE} bash -clx "./format.sh"

echo "Cleaning up"
rm format.sh

YAML_LINT=https://raw.githubusercontent.com/swiftlang/github-workflows/refs/heads/main/.github/workflows/configs/yamllint.yml
YAML_IMAGE=ubuntu:latest

echo "Downloading yamllint.yml"
curl -s ${YAML_LINT} > yamllint.yml

echo "Running yamllint"
/usr/local/bin/docker run  --rm  -v "$(pwd):/workspace" -w /workspace ${YAML_IMAGE} bash -clx "apt-get -qq update && apt-get -qq -y install yamllint && yamllint --strict --config-file /workspace/yamllint.yml .github"

echo "Cleaning up"
rm yamllint.yml

