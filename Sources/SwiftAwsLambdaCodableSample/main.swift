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

private struct Request: Codable {
    let body: String
}

private struct Response: Codable {
    let body: String
}

// in this example we are receiving and responding with codables. Request and Response above are examples of how to use
// codables to model your reqeuest and response objects
Lambda.run { (_, request: Request, callback) in
    callback(.success(Response(body: String(request.body.reversed()))))
}
