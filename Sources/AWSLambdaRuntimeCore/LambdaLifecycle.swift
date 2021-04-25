//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
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
import NIOConcurrencyHelpers

extension Lambda {
    /// `Lifecycle` manages the Lambda process lifecycle.
    ///
    /// - note: It is intended to be used within a single `EventLoop`. For this reason this class is not thread safe.
    public final class Lifecycle {
        private let runtime: Runtime

        /// Create a new `Lifecycle`.
        ///
        /// - parameters:
        ///     - eventLoop: An `EventLoop` to run the Lambda on.
        ///     - logger: A `Logger` to log the Lambda events.
        ///     - factory: A `LambdaHandlerFactory` to create the concrete  Lambda handler.
        public convenience init(eventLoop: EventLoop, logger: Logger, factory: @escaping HandlerFactory) {
            self.init(eventLoop: eventLoop, logger: logger, configuration: .init(), factory: factory)
        }

        init(eventLoop: EventLoop, logger: Logger, configuration: Configuration, factory: @escaping HandlerFactory) {
            self.runtime = Runtime(eventLoop: eventLoop, logger: logger, configuration: configuration, factory: factory)
        }

        /// The `Lifecycle` shutdown future.
        ///
        /// - Returns: An `EventLoopFuture` that is fulfilled after the Lambda lifecycle has fully shutdown.
        public var shutdownFuture: EventLoopFuture<Int> {
            self.runtime.shutdownFuture.map { _ in 1 }
        }

        /// Start the `Lifecycle`.
        ///
        /// - Returns: An `EventLoopFuture` that is fulfilled after the Lambda hander has been created and initiliazed, and a first run has been scheduled.
        ///
        /// - note: This method must be called  on the `EventLoop` the `Lifecycle` has been initialized with.
        public func start() -> EventLoopFuture<Void> {
            self.runtime.start()
        }

        // MARK: -  Private

        #if DEBUG
        /// Begin the `Lifecycle` shutdown. Only needed for debugging purposes, hence behind a `DEBUG` flag.
        public func shutdown() {
            // make this method thread safe by dispatching onto the eventloop
            _ = self.runtime.stop()
        }
        #endif
    }
}
