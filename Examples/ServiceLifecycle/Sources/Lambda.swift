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

import AWSLambdaRuntime
import Logging
import PostgresNIO
import ServiceLifecycle

@main
struct LambdaFunction {

    static func main() async throws {

        var logger = Logger(label: "ServiceLifecycleExample")
        logger.logLevel = .trace

        let pgClient = try preparePostgresClient(
            host: Lambda.env("DB_HOST") ?? "localhost",
            user: Lambda.env("DB_USER") ?? "postgres",
            password: Lambda.env("DB_PASSWORD") ?? "secret",
            dbName: Lambda.env("DB_NAME") ?? "test"
        )

        /// Instantiate LambdaRuntime with a closure handler implementing the business logic of the Lambda function
        let runtime = LambdaRuntimeService(logger: logger) { (event: String, context: LambdaContext) in

            do {
                // Use initialized service within the handler
                // IMPORTANT - CURRENTLY WHEN THERE IS AN ERROR, THIS CALL HANGS WHEN DB IS NOT REACHABLE
                // https://github.com/vapor/postgres-nio/issues/489
                let rows = try await pgClient.query("SELECT id, username FROM users")
                for try await (id, username) in rows.decode((Int, String).self) {
                    logger.debug("\(id) : \(username)")
                }
            } catch {
                logger.error("PG Error: \(error)")
            }
        }

        /// Use ServiceLifecycle to manage the initialization and termination
        /// of the PGClient together with the LambdaRuntime
        let serviceGroup = ServiceGroup(
            services: [pgClient, runtime],
            gracefulShutdownSignals: [.sigterm, .sigint],  // add SIGINT for CTRL+C in local testing
            // cancellationSignals: [.sigint],
            logger: logger
        )
        try await serviceGroup.run()

        // perform any cleanup here
    }

    private static func preparePostgresClient(
        host: String,
        user: String,
        password: String,
        dbName: String
    ) throws -> PostgresClient {

        var tlsConfig = TLSConfiguration.makeClientConfiguration()
        // Load the root certificate
        let rootCert = try NIOSSLCertificate.fromPEMBytes(Array(eu_central_1_bundle_pem.utf8))

        // Add the root certificate to the TLS configuration
        tlsConfig.trustRoots = .certificates(rootCert)

        // Enable full verification
        tlsConfig.certificateVerification = .fullVerification

        let config = PostgresClient.Configuration(
            host: host,
            port: 5432,
            username: user,
            password: password,
            database: dbName,
            tls: .prefer(tlsConfig)
        )

        return PostgresClient(configuration: config)
    }
}