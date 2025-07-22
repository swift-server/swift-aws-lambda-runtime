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

struct User: Codable {
    let id: Int
    let username: String
}

@main
struct LambdaFunction {

    static func main() async throws {
        try await LambdaFunction().main()
    }

    private let pgClient: PostgresClient
    private var logger: Logger
    private init() throws {
        self.logger = Logger(label: "ServiceLifecycleExample")

        self.pgClient = try LambdaFunction.preparePostgresClient(
            host: Lambda.env("DB_HOST") ?? "localhost",
            user: Lambda.env("DB_USER") ?? "postgres",
            password: Lambda.env("DB_PASSWORD") ?? "secret",
            dbName: Lambda.env("DB_NAME") ?? "test",
            logger: logger
        )
    }
    private func main() async throws {

        // Instantiate LambdaRuntime with a handler implementing the business logic of the Lambda function
        // ok when https://github.com/swift-server/swift-aws-lambda-runtime/pull/523 will be merged
        //let runtime = LambdaRuntime(logger: logger, body: handler)
        let runtime = LambdaRuntime(body: handler)

        /// Use ServiceLifecycle to manage the initialization and termination
        /// of the PGClient together with the LambdaRuntime
        let serviceGroup = ServiceGroup(
            services: [pgClient, runtime],
            gracefulShutdownSignals: [.sigterm],
            cancellationSignals: [.sigint],
            logger: logger
        )
        try await serviceGroup.run()

        // perform any cleanup here

    }

    private func handler(event: String, context: LambdaContext) async -> [User] {

        // input event is ignored here

        var result: [User] = []
        do {
            // Use initialized service within the handler
            // IMPORTANT - CURRENTLY WHEN THERE IS AN ERROR, THIS CALL HANGS WHEN DB IS NOT REACHABLE
            // https://github.com/vapor/postgres-nio/issues/489
            // this is why there is a timeout, as suggested by
            // https://github.com/vapor/postgres-nio/issues/489#issuecomment-2186509773
            logger.info("Connecting to the database")
            result = try await timeout(deadline: .seconds(3)) {
                let rows = try await pgClient.query("SELECT id, username FROM users")
                var users: [User] = []
                for try await (id, username) in rows.decode((Int, String).self) {
                    logger.info("Adding \(id) : \(username)")
                    users.append(User(id: id, username: username))
                }
                return users
            }
        } catch {
            logger.error("PG Error: \(error)")
        }
        return result
    }

    private static func preparePostgresClient(
        host: String,
        user: String,
        password: String,
        dbName: String,
        logger: Logger
    ) throws -> PostgresClient {

        // Load the root certificate
        let region = Lambda.env("AWS_REGION") ?? "us-east-1"
        guard let pem = rootRDSCertificates[region] else {
            logger.error("No root certificate found for the specified AWS region.")
            throw LambdaErrors.missingRootCertificateForRegion(region)
        }
        let certificatePEM = Array(pem.utf8)
        let rootCert = try NIOSSLCertificate.fromPEMBytes(certificatePEM)

        // Add the root certificate to the TLS configuration
        var tlsConfig = TLSConfiguration.makeClientConfiguration()
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

public enum LambdaErrors: Error {
    case missingRootCertificateForRegion(String)
}
