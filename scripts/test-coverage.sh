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

BIN_PATH="$(swift build --show-bin-path)"
XCTEST_PATH="$(find ${BIN_PATH} -name '*.xctest')"
COV_BIN=$XCTEST_PATH

if [[ "$OSTYPE" == "darwin"* ]]; then
  f="$(basename $XCTEST_PATH .xctest)"
  COV_BIN="${COV_BIN}/Contents/MacOS/$f"
	LLVM_COV="/opt/homebrew/opt/llvm/bin/llvm-cov"
else
  echo "Unsupported OS: $OSTYPE"
	exit -1
fi

${LLVM_COV} report \
  "${COV_BIN}" \
  -instr-profile=.build/debug/codecov/default.profdata \
  -ignore-filename-regex=".build|Tests" \
  -use-color