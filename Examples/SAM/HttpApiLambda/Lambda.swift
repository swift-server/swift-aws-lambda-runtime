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
struct HttpApiLambda: SimpleLambdaHandler {
  typealias Event = APIGatewayV2Request
  typealias Output = APIGatewayV2Response

  init() {}
  init(context: LambdaInitializationContext) async throws {
    context.logger.info(
      "Log Level env var : \(ProcessInfo.processInfo.environment["LOG_LEVEL"] ?? "info" )")
  }

  func handle(_ event: Event, context: AWSLambdaRuntimeCore.LambdaContext) async throws -> Output {

    var header = HTTPHeaders()
    do {
      context.logger.debug("HTTP API Message received")

      header["content-type"] = "application/json"

      // echo the request in the response
      let data = try JSONEncoder().encode(event)
      let response = String(data: data, encoding: .utf8)

      return Output(statusCode: .accepted, headers: header, body: response)

    } catch {
      header["content-type"] = "text/plain"
      return Output(statusCode: .badRequest, headers: header, body: "\(error.localizedDescription)")
    }
  }
}
