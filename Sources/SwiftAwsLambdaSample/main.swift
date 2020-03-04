//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAwsLambda open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftAwsLambda project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAwsLambda project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SwiftAwsLambda

// in this example we are receiving and responding with bytes (default)
Lambda.run { (_, payload: [UInt8], callback) in
    // as an example, respond with the reverse the input payload
    callback(.success(payload.reversed()))
}
