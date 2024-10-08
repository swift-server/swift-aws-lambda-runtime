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

set +ex

LAMBDA_USE_LOCAL_DEPS=true swift build --package-path Examples/APIGateway 
LAMBDA_USE_LOCAL_DEPS=true swift build --package-path Examples/AWSSDK 
LAMBDA_USE_LOCAL_DEPS=true swift build --package-path Examples/HelloWorld 
LAMBDA_USE_LOCAL_DEPS=true swift build --package-path Examples/Soto
