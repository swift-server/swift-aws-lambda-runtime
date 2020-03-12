//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAwsLambda open source project
//
// Copyright (c) 2017-2020 Apple Inc. and the SwiftAwsLambda project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAwsLambda project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Dispatch
import Logging
import NIO

extension Lambda {
    public final class Context {
        /// The request ID, which identifies the request that triggered the function invocation.
        public let requestId: String

        /// The AWS X-Ray tracing header.
        public let traceId: String

        /// The ARN of the Lambda function, version, or alias that's specified in the invocation.
        public let invokedFunctionArn: String

        /// The timestamp that the function times out
        public let deadline: DispatchWallTime

        /// For invocations from the AWS Mobile SDK, data about the Amazon Cognito identity provider.
        public let cognitoIdentity: String?

        /// For invocations from the AWS Mobile SDK, data about the client application and device.
        public let clientContext: String?

        /// a logger to log
        public let logger: Logger

        internal init(requestId: String,
                      traceId: String,
                      invokedFunctionArn: String,
                      deadline: DispatchWallTime,
                      cognitoIdentity: String? = nil,
                      clientContext: String? = nil,
                      logger: Logger) {
            self.requestId = requestId
            self.traceId = traceId
            self.invokedFunctionArn = invokedFunctionArn
            self.cognitoIdentity = cognitoIdentity
            self.clientContext = clientContext
            self.deadline = deadline
            // mutate logger with context
            var logger = logger
            logger[metadataKey: "awsRequestId"] = .string(requestId)
            logger[metadataKey: "awsTraceId"] = .string(traceId)
            self.logger = logger
        }

        public func getRemainingTime() -> TimeAmount {
            let deadline = self.deadline.millisSinceEpoch
            let now = DispatchWallTime.now().millisSinceEpoch

            let remaining = deadline - now
            return .milliseconds(remaining)
        }
    }
}
