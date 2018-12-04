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

import Foundation
import NIO

/// LambdaRunner manages the Lambda runtime workflow, or business logic.
internal final class LambdaRunner {
    private let lambdaHandler: LambdaHandler
    private let runtimeClient: LambdaRuntimeClient
    private let eventLoop: EventLoop

    init(eventLoop: EventLoop, lambdaHandler: LambdaHandler) {
        self.eventLoop = eventLoop
        self.lambdaHandler = lambdaHandler
        self.runtimeClient = LambdaRuntimeClient(eventLoop: eventLoop)
    }

    func run() -> EventLoopFuture<LambdaRunResult> {
        print("lambda invocation sequence starting")
        // 1. request work from lambda runtime engine
        return self.runtimeClient.requestWork().then { workRequestResult in
            switch workRequestResult {
            case let .failure(error):
                print("could not fetch work from lambda runtime engine: \(error)")
                return self.newSucceededFuture(result: .failure(error))
            case let .success(context, payload):
                // 2. send work to handler
                print("sending work to lambda handler \(self.lambdaHandler)")
                let promise: EventLoopPromise<LambdaResult> = self.eventLoop.newPromise()
                self.lambdaHandler.handle(context: context, payload: payload, promise: promise)
                return promise.futureResult.then { lambdaResult in
                    // 3. report results to runtime engine
                    self.runtimeClient.reportResults(context: context, result: lambdaResult).then { postResultsResult in
                        switch postResultsResult {
                        case let .failure(error):
                            print("could not report results to lambda runtime engine: \(error)")
                            return self.newSucceededFuture(result: .failure(error))
                        case .success():
                            // we are done!
                            print("lambda invocation sequence completed successfully")
                            return self.newSucceededFuture(result: .success(()))
                        }
                    }
                }
            }
        }
    }

    private func newSucceededFuture<T>(result: T) -> EventLoopFuture<T> {
        return self.eventLoop.newSucceededFuture(result: result)
    }
}

internal typealias LambdaRunResult = ResultType<(), Error>

private extension LambdaHandler {
    func handle(context: LambdaContext, payload: [UInt8], promise: EventLoopPromise<LambdaResult>) {
        // offloading so user code never blocks the eventloop
        DispatchQueue(label: "lambda-\(context.requestId)").async {
            self.handle(context: context, payload: payload, callback: { (result: LambdaResult) in
                promise.succeed(result: result)
            })
        }
    }
}
