//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AWSLambdaRuntimeCore
import struct Foundation.Date

extension Lambda.Context {
    var deadlineDate: Date {
        let secondsSinceEpoch = Double(Int64(bitPattern: self.deadline.rawValue)) / -1_000_000_000
        return Date(timeIntervalSince1970: secondsSinceEpoch)
    }
}
