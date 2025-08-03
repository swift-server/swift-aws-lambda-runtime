//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2025 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if ServiceLifecycleSupport
import ServiceLifecycle

extension LambdaRuntime: Service {
    public func run() async throws {
        await cancelWhenGracefulShutdown {
            do {
                try await self._run()
            } catch {
                // catch top level errors that have not been handled until now
                // this avoids the runtime to crash and generate a backtrace
                self.logger.error("LambdaRuntime.run() failed with error", metadata: ["error": "\(error)"])
            }
        }
    }
}
#endif
