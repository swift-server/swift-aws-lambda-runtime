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
// LambdaTest+XCTest.swift
//
import XCTest

///
/// NOTE: This file was generated by generate_linux_tests.rb
///
/// Do NOT edit this file directly as it will be regenerated automatically when needed.
///

extension LambdaTest {
    static var allTests: [(String, (LambdaTest) -> () throws -> Void)] {
        return [
            ("testSuceess", testSuceess),
            ("testFailure", testFailure),
            ("testServerFailure", testServerFailure),
            ("testBootstrapFailure", testBootstrapFailure),
            ("testBootstrapFailureAndReportErrorFailure", testBootstrapFailureAndReportErrorFailure),
            ("testProviderFailure", testProviderFailure),
            ("testProviderFailureAndReportErrorFailure", testProviderFailureAndReportErrorFailure),
            ("testStartStop", testStartStop),
            ("testTimeout", testTimeout),
            ("testDisconnect", testDisconnect),
            ("testBigPayload", testBigPayload),
            ("testKeepAliveServer", testKeepAliveServer),
            ("testNoKeepAliveServer", testNoKeepAliveServer),
        ]
    }
}
