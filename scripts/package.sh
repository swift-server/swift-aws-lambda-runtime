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

executable=$1

target=.build/lambda
rm -rf "$target"
mkdir -p "$target"
cp ".build/release/$executable" "$target/"
cp -Pv /usr/lib/swift/linux/lib*so* /usr/lib64/libatomic.so.1* "$target"
cd "$target"
ln -s "$executable" "bootstrap"
zip --symlinks lambda.zip *
