//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2022 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore

extension NewLambdaRuntime {
    struct Connection {
        var channel: Channel
        var handler: NewLambdaChannelHandler<NewLambdaRuntime>
    }

    struct StateMachine {
        enum Action {
            case none
            case createHandler(andConnection: Bool)

            case requestNextInvocation(NewLambdaChannelHandler<NewLambdaRuntime>, succeedStartPromise: EventLoopPromise<Void>?)

            case reportInvocationResult(LambdaRequestID, Result<ByteBuffer?, Error>, pipelineNextInvocationRequest: Bool, NewLambdaChannelHandler<NewLambdaRuntime>)
            case reportStartupError(Error, NewLambdaChannelHandler<NewLambdaRuntime>)

            case invokeHandler(Handler, Invocation, ByteBuffer)

            case failRuntime(Error, startPomise: EventLoopPromise<Void>?)
        }

        private enum State {
            case initialized
            case starting(EventLoopPromise<Void>?)
            case connected(Connection, EventLoopPromise<Void>?)
            case handlerCreated(Handler, EventLoopPromise<Void>?)
            case handlerCreationFailed(Error, EventLoopPromise<Void>?)
            case reportingStartupError(Connection, Error, EventLoopPromise<Void>?)

            case waitingForInvocation(Connection, Handler)
            case executingInvocation(Connection, Handler, LambdaRequestID)
            case reportingInvocationResult(Connection, Handler, nextInvocationRequestPipelined: Bool)

            case failed(Error)
        }

        private var markShutdown: Bool
        private var state: State

        init() {
            self.markShutdown = false
            self.state = .initialized
        }

        mutating func start(connection: Connection?, promise: EventLoopPromise<Void>?) -> Action {
            switch self.state {
            case .initialized:
                if let connection = connection {
                    self.state = .connected(connection, promise)
                    return .createHandler(andConnection: false)
                }

                self.state = .starting(promise)
                return .createHandler(andConnection: true)

            case .starting,
                 .connected,
                 .handlerCreated,
                 .handlerCreationFailed,
                 .reportingStartupError,
                 .waitingForInvocation,
                 .executingInvocation,
                 .reportingInvocationResult,
                 .failed:
                preconditionFailure("Invalid state: \(self.state)")
            }
        }

        mutating func handlerCreated(_ handler: Handler) -> Action {
            switch self.state {
            case .initialized,
                 .handlerCreated,
                 .handlerCreationFailed,
                 .waitingForInvocation,
                 .executingInvocation,
                 .reportingInvocationResult,
                 .reportingStartupError:
                preconditionFailure("Invalid state: \(self.state)")

            case .starting(let promise):
                self.state = .handlerCreated(handler, promise)
                return .none

            case .connected(let connection, let promise):
                self.state = .waitingForInvocation(connection, handler)
                return .requestNextInvocation(connection.handler, succeedStartPromise: promise)

            case .failed:
                return .none
            }
        }

        mutating func handlerCreationFailed(_ error: Error) -> Action {
            switch self.state {
            case .initialized,
                 .handlerCreated,
                 .handlerCreationFailed,
                 .waitingForInvocation,
                 .executingInvocation,
                 .reportingInvocationResult,
                 .reportingStartupError:
                preconditionFailure("Invalid state: \(self.state)")

            case .starting(let promise):
                self.state = .handlerCreationFailed(error, promise)
                return .none

            case .connected(let connection, let promise):
                self.state = .reportingStartupError(connection, error, promise)
                return .reportStartupError(error, connection.handler)

            case .failed:
                return .none
            }
        }

        mutating func httpConnectionCreated(
            _ connection: Connection
        ) -> Action {
            switch self.state {
            case .initialized,
                 .connected,
                 .waitingForInvocation,
                 .executingInvocation,
                 .reportingInvocationResult,
                 .reportingStartupError:
                preconditionFailure("Invalid state: \(self.state)")

            case .starting(let promise):
                self.state = .connected(connection, promise)
                return .none

            case .handlerCreated(let handler, let promise):
                self.state = .waitingForInvocation(connection, handler)
                return .requestNextInvocation(connection.handler, succeedStartPromise: promise)

            case .handlerCreationFailed(let error, let promise):
                self.state = .reportingStartupError(connection, error, promise)
                return .reportStartupError(error, connection.handler)

            case .failed:
                return .none
            }
        }

        mutating func httpChannelConnectFailed(_ error: Error) -> Action {
            switch self.state {
            case .initialized,
                 .connected,
                 .waitingForInvocation,
                 .executingInvocation,
                 .reportingInvocationResult,
                 .reportingStartupError:
                preconditionFailure("Invalid state: \(self.state)")

            case .starting(let promise):
                self.state = .failed(error)
                return .failRuntime(error, startPomise: promise)

            case .handlerCreated(_, let promise):
                self.state = .failed(error)
                return .failRuntime(error, startPomise: promise)

            case .handlerCreationFailed(let error, let promise):
                self.state = .failed(error)
                return .failRuntime(error, startPomise: promise)

            case .failed:
                return .none
            }
        }

        mutating func newInvocationReceived(_ invocation: Invocation, _ body: ByteBuffer) -> Action {
            switch self.state {
            case .initialized,
                 .starting,
                 .connected,
                 .handlerCreated,
                 .handlerCreationFailed,
                 .executingInvocation,
                 .reportingInvocationResult,
                 .reportingStartupError:
                preconditionFailure("Invalid state: \(self.state)")

            case .waitingForInvocation(let connection, let handler):
                self.state = .executingInvocation(connection, handler, LambdaRequestID(uuidString: invocation.requestID)!)
                return .invokeHandler(handler, invocation, body)

            case .failed:
                return .none
            }
        }

        mutating func acceptedReceived() -> Action {
            switch self.state {
            case .initialized,
                 .starting,
                 .connected,
                 .handlerCreated,
                 .handlerCreationFailed,
                 .executingInvocation:
                preconditionFailure("Invalid state: \(self.state)")

            case .waitingForInvocation:
                preconditionFailure("TODO: fixme")

            case .reportingStartupError(_, let error, let promise):
                self.state = .failed(error)
                return .failRuntime(error, startPomise: promise)

            case .reportingInvocationResult(let connection, let handler, true):
                self.state = .waitingForInvocation(connection, handler)
                return .none

            case .reportingInvocationResult(let connection, let handler, false):
                self.state = .waitingForInvocation(connection, handler)
                return .requestNextInvocation(connection.handler, succeedStartPromise: nil)

            case .failed:
                return .none
            }
        }

        mutating func errorResponseReceived(_ errorResponse: ErrorResponse) -> Action {
            switch self.state {
            case .initialized,
                 .starting,
                 .connected,
                 .handlerCreated,
                 .handlerCreationFailed,
                 .executingInvocation:
                preconditionFailure("Invalid state: \(self.state)")

            case .waitingForInvocation:
                let error = LambdaRuntimeError.controlPlaneErrorResponse(errorResponse)
                self.state = .failed(error)
                return .failRuntime(error, startPomise: nil)

            case .reportingStartupError(_, let error, let promise):
                self.state = .failed(error)
                return .failRuntime(error, startPomise: promise)

            case .reportingInvocationResult:
                let error = LambdaRuntimeError.controlPlaneErrorResponse(errorResponse)
                self.state = .failed(error)
                return .failRuntime(error, startPomise: nil)

            case .failed:
                return .none
            }
        }

        mutating func handlerError(_: Error) {}

        mutating func channelInactive() {}

        mutating func invocationFinished(_ result: Result<ByteBuffer?, Error>) -> Action {
            switch self.state {
            case .initialized,
                 .starting,
                 .handlerCreated,
                 .handlerCreationFailed,
                 .connected,
                 .waitingForInvocation,
                 .reportingStartupError,
                 .reportingInvocationResult:
                preconditionFailure("Invalid state: \(self.state)")

            case .failed:
                return .none

            case .executingInvocation(let connection, let handler, let requestID):
                let pipelining = true
                self.state = .reportingInvocationResult(connection, handler, nextInvocationRequestPipelined: pipelining)
                return .reportInvocationResult(requestID, result, pipelineNextInvocationRequest: pipelining, connection.handler)
            }
        }
    }
}
