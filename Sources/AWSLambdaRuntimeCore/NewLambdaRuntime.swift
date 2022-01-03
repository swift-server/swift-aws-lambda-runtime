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

import Logging
import NIOConcurrencyHelpers
import NIOCore
import NIOPosix

/// `LambdaRuntime` manages the Lambda process lifecycle.
///
/// - note: It is intended to be used within a single `EventLoop`. For this reason this class is not thread safe.
public final class NewLambdaRuntime<Handler: ByteBufferLambdaHandler> {
    private let eventLoop: EventLoop
    private let shutdownPromise: EventLoopPromise<Void>
    private let logger: Logger
    private let configuration: Lambda.Configuration
    private let factory: (Lambda.InitializationContext) -> EventLoopFuture<Handler>

    private var state: StateMachine

    init(eventLoop: EventLoop,
         logger: Logger,
         configuration: Lambda.Configuration,
         factory: @escaping (Lambda.InitializationContext) -> EventLoopFuture<Handler>
    ) {
        self.state = StateMachine()
        self.eventLoop = eventLoop
        self.shutdownPromise = eventLoop.makePromise(of: Void.self)
        self.logger = logger
        self.configuration = configuration
        self.factory = factory
    }

    deinit {
        // TODO: Verify is shutdown
    }

    /// The `Lifecycle` shutdown future.
    ///
    /// - Returns: An `EventLoopFuture` that is fulfilled after the Lambda lifecycle has fully shutdown.
    public var shutdownFuture: EventLoopFuture<Void> {
        self.shutdownPromise.futureResult
    }

    /// Start the `LambdaRuntime`.
    ///
    /// - Returns: An `EventLoopFuture` that is fulfilled after the Lambda hander has been created and initiliazed, and a first run has been scheduled.
    public func start(promise: EventLoopPromise<Void>?) {
        if self.eventLoop.inEventLoop {
            self.start0(promise: promise)
        } else {
            self.eventLoop.execute {
                self.start0(promise: promise)
            }
        }
    }
    
    /// Begin the `LambdaRuntime` shutdown. Only needed for debugging purposes, hence behind a `DEBUG` flag.
    public func shutdown(promise: EventLoopPromise<Void>?) {
        if self.eventLoop.inEventLoop {
            self.shutdown0(promise: promise)
        } else {
            self.eventLoop.execute {
                self.shutdown0(promise: promise)
            }
        }
    }
    
    // MARK: -  Private
    
    private func start0(promise: EventLoopPromise<Void>?) {
        self.eventLoop.assertInEventLoop()

        // when starting we want to do thing in parallel:
        //  1. start the connection to the control plane
        //  2. create the lambda handler
        
        self.logger.debug("initializing lambda")
        // 1. create the handler from the factory
        // 2. report initialization error if one occured
        let context = Lambda.InitializationContext(
            logger: self.logger,
            eventLoop: self.eventLoop,
            allocator: ByteBufferAllocator()
        )
        
        self.factory(context).hop(to: self.eventLoop).whenComplete { result in
            let action: StateMachine.Action
            switch result {
            case .success(let handler):
                action = self.state.handlerCreated(handler)
            case .failure(let error):
                action = self.state.handlerCreationFailed(error)
            }
            self.run(action)
        }
        
        let connectFuture = ClientBootstrap(group: self.eventLoop).connect(
            host: self.configuration.runtimeEngine.ip,
            port: self.configuration.runtimeEngine.port
        )

        connectFuture.whenComplete { result in
            let action: StateMachine.Action
            switch result {
            case .success(let channel):
                action = self.state.httpChannelConnected(channel)
            case .failure(let error):
                action = self.state.httpChannelConnectFailed(error)
            }
            self.run(action)
        }
    }
    
    private func shutdown0(promise: EventLoopPromise<Void>?) {
        
    }
    
    private func run(_ action: StateMachine.Action) {
        
    }
}

extension LambdaRuntime: LambdaChannelHandlerDelegate {
    func responseReceived(_ response: ControlPlaneResponse) {
        
    }
    
    func errorCaught(_: Error) {
        
    }
    
    func channelInactive() {
        
    }
}

extension NewLambdaRuntime {
    
    struct StateMachine {
        enum Action {
            case none
        }
        
        private enum State {
            case initialized
            case starting
            case channelConnected(Channel, NewLambdaChannelHandler<LambdaRuntime>)
            case handlerCreated(Handler)
            case running(Channel, NewLambdaChannelHandler<LambdaRuntime>, Handler)
        }
        
        private var markShutdown: Bool
        private var state: State
        
        init() {
            self.markShutdown = false
            self.state = .initialized
        }
        
        func handlerCreated(_ handler: Handler) -> Action {
            return .none
        }
        
        func handlerCreationFailed(_ error: Error) -> Action {
            return .none
        }
        
        func httpChannelConnected(_ channel: Channel) -> Action {
            return .none
        }
        
        func httpChannelConnectFailed(_ error: Error) -> Action {
            return .none
        }
    }
}
