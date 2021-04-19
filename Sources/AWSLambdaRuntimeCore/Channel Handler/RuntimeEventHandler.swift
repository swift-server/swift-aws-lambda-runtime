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
import Logging

enum RuntimeEvent {
    case startupCompleted
    case shutdownCompleted
}

final class RuntimeEventHandler: ChannelDuplexHandler {
    typealias InboundIn = Never
    typealias OutboundIn = Never
    
    enum State {
        case initialized
        case starting(EventLoopPromise<Void>)
        case running(EventLoopPromise<Void>)
        case stopping(EventLoopPromise<Void>)
        case stopped
    }
    
    private var state: State = .initialized
    
    private(set) var startupFuture: EventLoopFuture<Void>?
    private(set) var shutdownFuture: EventLoopFuture<Void>?
    
    init() {}
    
    func connect(context: ChannelHandlerContext, to address: SocketAddress, promise: EventLoopPromise<Void>?) {
        guard case .initialized = self.state else {
            preconditionFailure()
        }
        let startupPromise = context.eventLoop.makePromise(of: Void.self)
        self.state = .starting(startupPromise)
        self.startupFuture = startupPromise.futureResult
        context.connect(to: address, promise: promise)
    }
    
    func close(context: ChannelHandlerContext, mode: CloseMode, promise: EventLoopPromise<Void>?) {
        guard case .running(let promise) = self.state else {
            preconditionFailure()
        }
        
        self.state = .stopping(promise)
        context.close(mode: mode, promise: promise)
    }
    
    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        switch event {
        case RuntimeEvent.startupCompleted:
            guard case .starting(let startupPromise) = self.state else {
                preconditionFailure()
            }
            
            let shutdownPromise = context.eventLoop.makePromise(of: Void.self)
            self.shutdownFuture = shutdownPromise.futureResult
            self.state = .running(shutdownPromise)
            startupPromise.succeed(())
        default:
            preconditionFailure()
        }
        
        context.fireUserInboundEventTriggered(event)
    }
    
    func channelInactive(context: ChannelHandlerContext) {
        switch self.state {
        case .running(let promise), .stopping(let promise):
            promise.succeed(())
        default:
            break
        }
        
        context.fireChannelInactive()
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        switch self.state {
        case .starting(let startupPromise):
            startupPromise.fail(error)
        case .running(let shutdownPromise), .stopping(let shutdownPromise):
            shutdownPromise.fail(error)
        default:
            preconditionFailure()
        }
        
        context.fireErrorCaught(error)
    }
}
