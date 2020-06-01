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

import AWSLambdaRuntime
import Shared

// set LOCAL_LAMBDA_SERVER_ENABLED env variable to "true" to start
// a local server simulator which will allow local debugging
Lambda.run { (_, request: Request, callback: @escaping (Result<Response, Error>) -> Void) in
    // TODO: something useful
    callback(.success(Response(message: "Hello, \(request.name)!")))
}
