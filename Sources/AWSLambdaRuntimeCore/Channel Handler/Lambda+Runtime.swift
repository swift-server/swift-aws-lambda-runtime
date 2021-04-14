//
//  File.swift
//  
//
//  Created by Fabian Fett on 13.04.21.
//

import NIO
import NIOHTTP1
import Logging

extension Lambda {
    
    public class Runtime<H: Handler> {
        
        @usableFromInline
        enum State {
            case initialized(factory: (InitializationContext) -> EventLoopFuture<H>)
            case starting
            case running(Channel)
            case shuttingdown
            case shutdown
        }
        
        @usableFromInline
        let eventLoop: EventLoop
        
        @usableFromInline
        let logger: Logger
        
        @usableFromInline
        let configuration: Configuration
        
        public var closeFuture: EventLoopFuture<Void>! {
            guard case .running(let channel) = self.state else {
                return nil
            }
            
            return channel.closeFuture
        }
        
        @usableFromInline
        /* private */ var state: State
        
        @inlinable
        public convenience init(eventLoop: EventLoop, logger: Logger, factory: @escaping (InitializationContext) -> EventLoopFuture<H>) {
            self.init(eventLoop: eventLoop, logger: logger, configuration: .init(), factory: factory)
        }
        
        @inlinable
        init(eventLoop: EventLoop, logger: Logger, configuration: Configuration, factory: @escaping (InitializationContext) -> EventLoopFuture<H>) {
            self.eventLoop = eventLoop
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
                        RuntimeAPICoder(host: "\(self.configuration.runtimeEngine.ip):\(self.configuration.runtimeEngine.port)"))
                    try channel.pipeline.syncOperations.addHandler(
                        RuntimeHandler(maxTimes: self.configuration.lifecycle.maxTimes, logger: self.logger, factory: factory))
                    
                    return channel.eventLoop.makeSucceededFuture(())
                } catch {
                    return channel.eventLoop.makeFailedFuture(error)
                }
            }
            
            return bootstrap.connect(host: self.configuration.runtimeEngine.ip, port: self.configuration.runtimeEngine.port)
                .map { channel in
                    self.state = .running(channel)
                    
                    channel.closeFuture.whenComplete { result in
                        self.state = .shutdown
                    }
                }
        }
        
        public func stop() -> EventLoopFuture<Void> {
            guard self.eventLoop.inEventLoop else {
                return self.eventLoop.flatSubmit {
                    self.stop()
                }
            }
            
            guard case .running(let channel) = self.state else {
                preconditionFailure()
            }
            
            self.state = .shuttingdown
            
            return channel.close(mode: .all)
        }
    }
}
