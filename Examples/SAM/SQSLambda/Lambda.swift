// ===----------------------------------------------------------------------===//
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
// ===----------------------------------------------------------------------===//

import AWSLambdaEvents
import AWSLambdaRuntime
import Foundation

@main
struct SQSLambda: SimpleLambdaHandler {
  typealias Event = SQSEvent
  typealias Output = Void

  init() {}
  init(context: LambdaInitializationContext) async throws {
    context.logger.info(
      "Log Level env var : \(ProcessInfo.processInfo.environment["LOG_LEVEL"] ?? "info" )")
  }

 func handle(_ event: Event, context: AWSLambdaRuntimeCore.LambdaContext) async throws -> Output {

    context.logger.info("Log Level env var : \(ProcessInfo.processInfo.environment["LOG_LEVEL"] ?? "not defined" )" )
    context.logger.debug("SQS Message received, with \(event.records.count) record")

    for msg in event.records {
      context.logger.debug("Message ID   : \(msg.messageId)")
      context.logger.debug("Message body : \(msg.body)")
    }
  }
}
