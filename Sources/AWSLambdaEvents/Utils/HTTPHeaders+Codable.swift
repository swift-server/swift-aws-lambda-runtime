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

import NIOHTTP1

extension HTTPHeaders {
    init(awsHeaders: [String: [String]]) {
        var nioHeaders: [(String, String)] = []
        awsHeaders.forEach { key, values in
            values.forEach { value in
                nioHeaders.append((key, value))
            }
        }

        self = HTTPHeaders(nioHeaders)
    }
}
