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

// as suggested by https://github.com/vapor/postgres-nio/issues/489#issuecomment-2186509773
func timeout<Success: Sendable>(
    deadline: Duration,
    _ closure: @escaping @Sendable () async throws -> Success
) async throws -> Success {

    let clock = ContinuousClock()

    let result = await withTaskGroup(of: TimeoutResult<Success>.self, returning: Result<Success, any Error>.self) {
        taskGroup in
        taskGroup.addTask {
            do {
                try await clock.sleep(until: clock.now + deadline, tolerance: nil)
                return .deadlineHit
            } catch {
                return .deadlineCancelled
            }
        }

        taskGroup.addTask {
            do {
                let success = try await closure()
                return .workFinished(.success(success))
            } catch let error {
                return .workFinished(.failure(error))
            }
        }

        var r: Swift.Result<Success, any Error>?
        while let taskResult = await taskGroup.next() {
            switch taskResult {
            case .deadlineCancelled:
                continue  // loop

            case .deadlineHit:
                taskGroup.cancelAll()

            case .workFinished(let result):
                taskGroup.cancelAll()
                r = result
            }
        }
        return r!
    }

    return try result.get()
}

enum TimeoutResult<Success: Sendable> {
    case deadlineHit
    case deadlineCancelled
    case workFinished(Result<Success, any Error>)
}
