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

import NIO

public final class Lambda {
    public class func run(_ closure: @escaping LambdaClosure) -> LambdaLifecycleResult {
        return run(LambdaClosureWrapper(closure))
    }

    public class func run(_ handler: LambdaHandler) -> LambdaLifecycleResult {
        return Lifecycle(handler: handler).start()
    }

    // for testing
    internal class func run(closure: @escaping LambdaClosure, maxTimes: Int) -> LambdaLifecycleResult {
        return run(handler: LambdaClosureWrapper(closure), maxTimes: maxTimes)
    }

    // for testing
    internal class func run(handler: LambdaHandler, maxTimes: Int) -> LambdaLifecycleResult {
        return Lifecycle(handler: handler, maxTimes: maxTimes).start()
    }

    private class Lifecycle {
        private let handler: LambdaHandler
        private let max: Int
        private var counter: Int = 0

        public init(handler: LambdaHandler, maxTimes: Int = 0) {
            self.handler = handler
            max = maxTimes
            assert(max >= 0)
        }

        func start() -> LambdaLifecycleResult {
            var err: Error?
            let runner = LambdaRunner(handler)
            while nil == err && (0 == max || counter < max) {
                do {
                    // blocking! per aws lambda runtime spec the polling requets are to be done one at a time
                    let result = try runner.run().wait()
                    switch result {
                    case .success:
                        counter = counter + 1
                    case let .failure(e):
                        err = e
                    }
                } catch {
                    err = error
                }
            }
            return err.map { _ in .failure(err!) } ?? .success(counter)
        }
    }
}

public enum LambdaResult<Value, Error> {
    case success(Value)
    case failure(Error)
}

public typealias LambdaLifecycleResult = LambdaResult<Int, Error>

public typealias LambdaCallback = (LambdaResult<[UInt8], String>) -> Void

public typealias LambdaClosure = (LambdaContext, [UInt8], LambdaCallback) -> Void

public protocol LambdaHandler {
    func handle(context: LambdaContext, payload: [UInt8], callback: @escaping LambdaCallback)
}

private class LambdaClosureWrapper: LambdaHandler {
    private let closure: LambdaClosure
    init(_ closure: @escaping LambdaClosure) {
        self.closure = closure
    }

    func handle(context: LambdaContext, payload: [UInt8], callback: @escaping LambdaCallback) {
        closure(context, payload, callback)
    }
}
