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

extension Lambda {
    public class func run(_ closure: @escaping LambdaStringClosure) -> LambdaLifecycleResult {
        return run(LambdaClosureWrapper(closure))
    }

    public class func run(_ handler: LambdaStringHandler) -> LambdaLifecycleResult {
        return run(handler as LambdaHandler)
    }

    // for testing
    internal class func run(closure: @escaping LambdaStringClosure, maxTimes: Int) -> LambdaLifecycleResult {
        return run(handler: LambdaClosureWrapper(closure), maxTimes: maxTimes)
    }

    // for testing
    internal class func run(handler: LambdaStringHandler, maxTimes: Int) -> LambdaLifecycleResult {
        return run(handler: handler as LambdaHandler, maxTimes: maxTimes)
    }
}

public typealias LambdaStringResult = Result<String, String>

public typealias LambdaStringCallback = (LambdaStringResult) -> Void

public typealias LambdaStringClosure = (LambdaContext, String, LambdaStringCallback) -> Void

public protocol LambdaStringHandler: LambdaHandler {
    func handle(context: LambdaContext, payload: String, callback: @escaping LambdaStringCallback)
}

public extension LambdaStringHandler {
    func handle(context: LambdaContext, payload: [UInt8], callback: @escaping LambdaCallback) {
        guard let payloadAsString = String(bytes: payload, encoding: .utf8) else {
            return callback(.failure("failed casting payload to String"))
        }
        handle(context: context, payload: payloadAsString, callback: { result in
            switch result {
            case let .success(string):
                return callback(.success([UInt8](string.utf8)))
            case let .failure(error):
                return callback(.failure(error))
            }
        })
    }
}

private class LambdaClosureWrapper: LambdaStringHandler {
    private let closure: LambdaStringClosure
    init(_ closure: @escaping LambdaStringClosure) {
        self.closure = closure
    }

    func handle(context: LambdaContext, payload: String, callback: @escaping LambdaStringCallback) {
        closure(context, payload, callback)
    }
}
