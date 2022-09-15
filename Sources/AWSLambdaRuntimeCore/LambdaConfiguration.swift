//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2021 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Dispatch
import Logging
import NIOCore

internal struct LambdaConfiguration: CustomStringConvertible {
    var general: General = .init()
    var lifecycle: Lifecycle = .init()
    var runtimeEngine: RuntimeEngine = .init()

    struct General: CustomStringConvertible {
        var logLevel = Lambda.env("LOG_LEVEL").flatMap(Logger.Level.init) ?? .info

        var description: String {
            "\(General.self)(logLevel: \(self.logLevel))"
        }
    }

    struct Lifecycle: CustomStringConvertible {
        var id: String = "\(DispatchTime.now().uptimeNanoseconds)"
        var stopSignal: Signal = Lambda.env("STOP_SIGNAL").flatMap(Int32.init).flatMap(Signal.init) ?? Signal.TERM
        var maxTimes: Int = Lambda.env("MAX_REQUESTS").flatMap(Int.init) ?? 0 {
            didSet { precondition(self.maxTimes >= 0, "maxTimes must be equal or larger than 0") }
        }

        var description: String {
            "\(Lifecycle.self)(id: \(self.id), maxTimes: \(self.maxTimes), stopSignal: \(self.stopSignal))"
        }
    }

    struct RuntimeEngine: CustomStringConvertible {
        let ip: String
        let port: Int
        let requestTimeout: TimeAmount?

        init(address: String? = nil, keepAlive: Bool? = nil, requestTimeout: TimeAmount? = nil) {
            let ipPort = (address ?? Lambda.env("AWS_LAMBDA_RUNTIME_API"))?.split(separator: ":") ?? ["127.0.0.1", "7000"]
            guard ipPort.count == 2, let port = Int(ipPort[1]) else {
                preconditionFailure("invalid ip+port configuration \(ipPort)")
            }
            self.ip = String(ipPort[0])
            self.port = port
            self.requestTimeout = requestTimeout ?? Lambda.env("REQUEST_TIMEOUT").flatMap(Int64.init).flatMap { .milliseconds($0) }
        }

        var description: String {
            "\(RuntimeEngine.self)(ip: \(self.ip), port: \(self.port), requestTimeout: \(String(describing: self.requestTimeout))"
        }
    }

    var description: String {
        "\(Self.self)\n  \(self.general))\n  \(self.lifecycle)\n  \(self.runtimeEngine)"
    }
}
