//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright SwiftAWSLambdaRuntime project authors
// Copyright (c) Amazon.com, Inc. or its affiliates.
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if FoundationJSONSupport
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import struct Foundation.Date
#endif

@available(LambdaSwift 2.0, *)
extension LambdaContext {
    /// Returns the deadline as a Date for the Lambda function execution.
    /// I'm not sure how usefull it is to have this as a Date, with only seconds precision,
    /// but I leave it here for compatibility with the FoundationJSONSupport trait.
    var deadlineDate: Date {
        // Date(timeIntervalSince1970:) expects seconds, so we convert milliseconds to seconds.
        Date(timeIntervalSince1970: Double(self.deadline.millisecondsSinceEpoch()) / 1000)
    }
}
#endif  // trait: FoundationJSONSupport
