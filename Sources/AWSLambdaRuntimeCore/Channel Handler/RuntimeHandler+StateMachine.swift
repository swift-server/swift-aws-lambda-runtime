//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO

extension RuntimeHandler {
    struct StateMachine {
        enum InvocationState {
            case waitingForNextInvocation
            case runningHandler(requestID: String)
            case reportingResult
        }

        enum State {
            case initialized(factory: (Lambda.InitializationContext) -> EventLoopFuture<ByteBufferLambdaHandler>)
            case starting(handler: Result<ByteBufferLambdaHandler, Error>?, connected: Bool)
            case started(handler: ByteBufferLambdaHandler)
            case running(ByteBufferLambdaHandler, state: InvocationState)
            case shuttingDown
            case reportingInitializationError(Error)
            case reportingInitializationErrorToChannel(Error)
            case shutdown
        }

        enum Action {
            case connect(to: SocketAddress, promise: EventLoopPromise<Void>?, andInitializeHandler: (Lambda.InitializationContext) -> EventLoopFuture<ByteBufferLambdaHandler>)
            case reportStartupSuccessToChannel
            case reportStartupFailureToChannel(Error)
            case getNextInvocation
            case invokeHandler(ByteBufferLambdaHandler, Invocation, ByteBuffer, Int)
            case reportInvocationResult(requestID: String, Result<ByteBuffer?, Error>)
            case reportInitializationError(Error)
            case closeConnection
            case fireChannelInactive
            case wait
        }

        private var state: State
        private var markShutdown: Bool = false
        private let maxTimes: Int
        private var invocationCount = 0

        init(maxTimes: Int, factory: @escaping (Lambda.InitializationContext) -> EventLoopFuture<ByteBufferLambdaHandler>) {
            self.maxTimes = maxTimes
            self.state = .initialized(factory: factory)
        }

        #if DEBUG
        init(state: State, maxTimes: Int) {
            self.state = state
            self.maxTimes = maxTimes
        }
        #endif

        mutating func connect(to address: SocketAddress, promise: EventLoopPromise<Void>?) -> Action {
            guard case .initialized(let factory) = self.state else {
                preconditionFailure()
            }

            self.state = .starting(handler: nil, connected: false)
            return .connect(to: address, promise: promise, andInitializeHandler: factory)
        }

        mutating func connected() -> Action {
            switch self.state {
            case .starting(.some(.success(let handler)), connected: false):
                self.state = .started(handler: handler)
                return .reportStartupSuccessToChannel
            case .starting(.some(.failure(let error)), connected: false):
                self.state = .reportingInitializationError(error)
                return .reportInitializationError(error)
            case .starting(.none, connected: false):
                self.state = .starting(handler: .none, connected: true)
                return .wait
            default:
                preconditionFailure()
            }
        }

        mutating func handlerInitialized(_ handler: ByteBufferLambdaHandler) -> Action {
            switch self.state {
            case .starting(.none, connected: false):
                self.state = .starting(handler: .success(handler), connected: false)
                return .wait
            case .starting(.none, connected: true):
                self.state = .started(handler: handler)
                return .reportStartupSuccessToChannel
            default:
                preconditionFailure()
            }
        }

        mutating func handlerFailedToInitialize(_ error: Error) -> Action {
            switch self.state {
            case .starting(.none, connected: false):
                self.state = .starting(handler: .failure(error), connected: false)
                return .wait
            case .starting(.none, connected: true):
                self.state = .reportingInitializationError(error)
                return .reportInitializationError(error)
            default:
                preconditionFailure()
            }
        }

        mutating func startupSuccessToChannelReported() -> Action {
            guard case .started(let handler) = self.state else {
                preconditionFailure()
            }

            self.state = .running(handler, state: .waitingForNextInvocation)
            return .getNextInvocation
        }

        mutating func startupFailureToChannelReported() -> Action {
            guard case .reportingInitializationErrorToChannel = self.state else {
                preconditionFailure()
            }

            self.state = .shuttingDown
            return .closeConnection
        }

        mutating func nextInvocationReceived(_ invocation: Invocation, _ bytes: ByteBuffer) -> Action {
            guard case .running(let handler, .waitingForNextInvocation) = self.state else {
                preconditionFailure()
            }

            self.invocationCount += 1
            self.state = .running(handler, state: .runningHandler(requestID: invocation.requestID))
            return .invokeHandler(handler, invocation, bytes, self.invocationCount)
        }

        mutating func invocationCompleted(_ result: Result<ByteBuffer?, Error>) -> Action {
            guard case .running(let handler, .runningHandler(let requestID)) = self.state else {
                preconditionFailure("Invalid state: \(self.state)")
            }

            self.state = .running(handler, state: .reportingResult)
            return .reportInvocationResult(requestID: requestID, result)
        }

        mutating func acceptedReceived() -> Action {
            switch self.state {
            case .running(_, state: .reportingResult) where self.markShutdown == true || (self.maxTimes > 0 && self.invocationCount == self.maxTimes):
                self.state = .shuttingDown
                return .closeConnection
                
            case .running(let handler, state: .reportingResult):
                self.state = .running(handler, state: .waitingForNextInvocation)
                return .getNextInvocation
                
            case .reportingInitializationError(let error):
                self.state = .reportingInitializationErrorToChannel(error)
                return .reportStartupFailureToChannel(error)
            
            case .initialized,
                 .starting,
                 .started,
                 .reportingInitializationErrorToChannel,
                 .running(_, state: .waitingForNextInvocation),
                 .running(_, state: .runningHandler),
                 .shuttingDown,
                 .shutdown:
                preconditionFailure("Invalid state: \(self.state)")
            }
        }

        mutating func close() -> Action {
            switch self.state {
            case .running(_, state: .waitingForNextInvocation):
                self.state = .shuttingDown
                return .closeConnection
            case .running(_, state: _):
                self.markShutdown = true
                return .wait
            default:
                preconditionFailure()
            }
        }

        mutating func channelInactive() -> Action {
            switch self.state {
            case .shuttingDown:
                self.state = .shutdown
                return .fireChannelInactive
            case .initialized, .shutdown, .starting(_, connected: false):
                preconditionFailure("Invalid state: \(self.state)")
            case .starting(_, connected: true):
                preconditionFailure("Todo: Unexpected connection closure during startup")
            case .started:
                preconditionFailure("Todo: Unexpected connection closure during startup")
            case .running(_, state: .waitingForNextInvocation):
                self.state = .shutdown
                return .fireChannelInactive
            case .running(_, state: .runningHandler):
                preconditionFailure("Todo: Unexpected connection closure")
            case .running(_, state: .reportingResult):
                preconditionFailure("Todo: Unexpected connection closure")
            case .reportingInitializationError:
                preconditionFailure("Todo: Unexpected connection closure during startup")
            case .reportingInitializationErrorToChannel(_):
                self.state = .shutdown
                return .fireChannelInactive

            }
        }

        mutating func errorMessageReceived(_: ErrorResponse) -> Action {
            preconditionFailure()
        }

        mutating func errorHappened(_: Error) -> Action {
            self.state = .shuttingDown
            return .closeConnection
        }
    }
}
