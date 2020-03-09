//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAwsLambda open source project
//
// Copyright (c) 2017-2019 Apple Inc. and the SwiftAwsLambda project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAwsLambda project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
//
// LambdaRuntimeClientTest+XCTest.swift
//
import XCTest

///
/// NOTE: This file was generated by generate_linux_tests.rb
///
/// Do NOT edit this file directly as it will be regenerated automatically when needed.
///

extension LambdaRuntimeClientTest {
    static var allTests: [(String, (LambdaRuntimeClientTest) -> () throws -> Void)] {
        return [
            ("testSuccess", testSuccess),
            ("testFailure", testFailure),
            ("testBootstrapFailure", testBootstrapFailure),
            ("testGetWorkServerInternalError", testGetWorkServerInternalError),
            ("testGetWorkServerNoBodyError", testGetWorkServerNoBodyError),
            ("testGetWorkServerMissingHeaderRequestIDError", testGetWorkServerMissingHeaderRequestIDError),
            ("testProcessResponseInternalServerError", testProcessResponseInternalServerError),
            ("testProcessErrorInternalServerError", testProcessErrorInternalServerError),
            ("testProcessInitErrorOnBootstrapFailure", testProcessInitErrorOnBootstrapFailure),
        ]
    }
}
