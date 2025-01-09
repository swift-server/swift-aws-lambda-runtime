import AWSLambdaRuntime
import Logging
import PostgresNIO
import ServiceLifecycle

@main
struct LambdaFunction {

    static func main() async throws {

        var logger = Logger(label: "Example")
        logger.logLevel = .trace

        var tlsConfig = TLSConfiguration.makeClientConfiguration()
        // Load the root certificate
        let rootCert = try NIOSSLCertificate.fromPEMBytes(Array(eu_central_1_bundle_pem.utf8))

        // Add the root certificate to the TLS configuration
        tlsConfig.trustRoots = .certificates(rootCert)

        // Enable full verification
        tlsConfig.certificateVerification = .fullVerification

        let config = PostgresClient.Configuration(
            host: Lambda.env("DB_HOST") ?? "localhost",
            port: 5432,
            username: Lambda.env("DB_USER") ?? "postgres",
            password: Lambda.env("DB_PASSWORD") ?? "",
            database: Lambda.env("DB_NAME") ?? "test",
            tls: .prefer(tlsConfig)
        )

        let postgresClient = PostgresClient(configuration: config)

        /// Instantiate LambdaRuntime with a closure handler implementing the business logic of the Lambda function
        let runtime = LambdaRuntimeService { (event: String, context: LambdaContext) in
            /// Use initialized service within the handler
            let rows = try await postgresClient.query("SELECT id, username FROM users")
            for try await (id, username) in rows.decode((Int, String).self) {
                logger.trace("\(id) : \(username)")
            }
        }

        /// Use ServiceLifecycle to manage the initialization and termination
        /// of the services as well as the LambdaRuntime
        let serviceGroup = ServiceGroup(
            services: [postgresClient, runtime],
            gracefulShutdownSignals: [.sigterm],
            logger: logger
        )
        try await serviceGroup.run()
    }
}
