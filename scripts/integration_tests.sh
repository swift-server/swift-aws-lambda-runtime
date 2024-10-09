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

set +x -e

for EXAMPLE in $(find Examples -type d -d 1);
do
	echo "Building $EXAMPLE"
	pushd $EXAMPLE
	LAMBDA_USE_LOCAL_DEPS=../.. swift build
	popd
done 
