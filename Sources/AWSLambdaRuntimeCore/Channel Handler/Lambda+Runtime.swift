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

import Logging
import NIO
import NIOHTTP1

extension Lambda {
    public class Runtime {
        enum State {
            case initialized(factory: (InitializationContext) -> EventLoopFuture<ByteBufferLambdaHandler>)
            case starting
            case running(Channel)
            case shuttingDown
            case shutdown
        }

        let shutdownPromise: EventLoopPromise<Void>

        let eventLoop: EventLoop

        let logger: Logger

        let configuration: Configuration

        public var shutdownFuture: EventLoopFuture<Void> {
            self.shutdownPromise.futureResult
        }

        private var state: State

        public convenience init(eventLoop: EventLoop, logger: Logger, factory: @escaping (InitializationContext) -> EventLoopFuture<ByteBufferLambdaHandler>) {
            self.init(eventLoop: eventLoop, logger: logger, configuration: .init(), factory: factory)
        }

        init(eventLoop: EventLoop, logger: Logger, configuration: Configuration, factory: @escaping (InitializationContext) -> EventLoopFuture<ByteBufferLambdaHandler>) {
            self.eventLoop = eventLoop
            self.shutdownPromise = eventLoop.makePromise(of: Void.self)
            self.logger = logger
            self.configuration = configuration
            self.state = .initialized(factory: factory)
        }

        deinit {
            guard case .shutdown = self.state else {
                preconditionFailure("invalid state \(self.state)")
            }
        }

        public func start() -> EventLoopFuture<Void> {
            guard self.eventLoop.inEventLoop else {
                return self.eventLoop.flatSubmit {
                    self.start()
                }
            }

            guard case .initialized(let factory) = self.state else {
                preconditionFailure()
            }

            self.state = .starting

            let bootstrap = ClientBootstrap(group: self.eventLoop).channelInitializer { channel in
                do {
                    try channel.pipeline.syncOperations.addHTTPClientHandlers()
                    // Lambda quotas... An invocation payload is maximal 6MB in size:
                    //   https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html
                    try channel.pipeline.syncOperations.addHandler(
                        NIOHTTPClientResponseAggregator(maxContentLength: 6 * 1024 * 1024))
                    try channel.pipeline.syncOperations.addHandler(
                        RuntimeHandler(configuration: self.configuration, logger: self.logger, factory: factory))
                    try channel.pipeline.syncOperations.addHandler(
                        RuntimeEventHandler())

                    return channel.eventLoop.makeSucceededFuture(())
                } catch {
                    return channel.eventLoop.makeFailedFuture(error)
                }
            }

            return bootstrap.connect(host: self.configuration.runtimeEngine.ip, port: self.configuration.runtimeEngine.port)
                .flatMapErrorThrowing { error in
                    self.logger.error("""
                        Could not connect to Lambda control plane. Are you sure you run your \
                        Lambda in AWS Lambda or in local development mode?
                        """,
                        metadata: ["underlyingError": "\(error)"])
                    throw error
                }
                .flatMap { channel in
                    // connected
                    channel.pipeline.handler(type: RuntimeEventHandler.self).flatMap { handler in
                        handler.startupFuture!.always { result in
                            switch result {
                            case .success:
                                self.state = .running(channel)
                                handler.shutdownFuture!.whenComplete { _ in
                                    self.state = .shutdown
                                }
                                handler.shutdownFuture!.cascade(to: self.shutdownPromise)
                                
                            case .failure(let error):
                                self.shutdownPromise.fail(error)
                                self.state = .shutdown
                            }
                        }
                    }
                }
        }

        public func stop() -> EventLoopFuture<Void> {
            self.logger.trace("Runtime stop triggered.")
            
            guard self.eventLoop.inEventLoop else {
                return self.eventLoop.flatSubmit {
                    self.stop()
                }
            }

            guard case .running(let channel) = self.state else {
                preconditionFailure()
            }

            self.state = .shuttingDown

            return channel.close(mode: .all)
        }
    }
}

extension Lambda {
    internal enum RuntimeError: Error {
        case badStatusCode(HTTPResponseStatus)
        case upstreamError(String)
        case invocationMissingHeader(String)
        case noBody
        case json(Error)
        case shutdownError(shutdownError: Error, runnerResult: Result<Int, Error>)
    }
}
