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

import AWSLambdaEvents
import AWSLambdaRuntime

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

let runtime = LambdaRuntime { (event: S3Event, context: LambdaContext) async throws in
    context.logger.debug("Received S3 event: \(event)")

    guard let s3NotificationRecord = event.records.first else {
        context.logger.error("No S3 notification record found in the event")
        return
    }

    let bucket = s3NotificationRecord.s3.bucket.name
    let key = s3NotificationRecord.s3.object.key.replacingOccurrences(of: "+", with: " ")

    context.logger.info("Received notification from S3 bucket '\(bucket)' for object with key '\(key)'")

    // Here you could, for example, notify an API or a messaging service
}

try await runtime.run()
