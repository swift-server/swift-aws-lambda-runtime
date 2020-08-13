//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import XCTest

import AWSLambdaEventsTests
import AWSLambdaRuntimeCoreTests
import AWSLambdaRuntimeTests
import AWSLambdaTestingTests

var tests = [XCTestCaseEntry]()
tests += AWSLambdaEventsTests.__allTests()
tests += AWSLambdaRuntimeCoreTests.__allTests()
tests += AWSLambdaRuntimeTests.__allTests()
tests += AWSLambdaTestingTests.__allTests()

XCTMain(tests)
