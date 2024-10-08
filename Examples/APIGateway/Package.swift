// swift-tools-version:6.0

import PackageDescription

// needed for CI to test the local version of the library
import class Foundation.ProcessInfo
import struct Foundation.URL

#if os(macOS)
let platforms: [PackageDescription.SupportedPlatform]? = [.macOS(.v15)]
#else
let platforms: [PackageDescription.SupportedPlatform]? = nil
#endif

let package = Package(
    name: "swift-aws-lambda-runtime-example",
    platforms: platforms,
    products: [
        .executable(name: "APIGatewayLambda", targets: ["APIGatewayLambda"])
    ],
    dependencies: [
        // dependency on swift-aws-lambda-runtime is added dynamically below
        // .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", branch: "main")

        .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "APIGatewayLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
            ],
            path: "."
        )
    ]
)

if let localDepsPath = ProcessInfo.processInfo.environment["LAMBDA_USE_LOCAL_DEPS"],
    localDepsPath != "",
    let v = try? URL(fileURLWithPath: localDepsPath).resourceValues(forKeys: [.isDirectoryKey]),
    let _ = v.isDirectory
{
    print("[INFO] Compiling against swift-aws-lambda-runtime located at \(localDepsPath)")
    package.dependencies += [
        .package(name: "swift-aws-lambda-runtime", path: localDepsPath)
    ]

} else {
    print("[INFO] LAMBDA_USE_LOCAL_DEPS is not pointing to your local swift-aws-lambda-runtime code")
    print("[INFO] This project will compile against the main branch of the Lambda Runtime on GitHub")
    package.dependencies += [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", branch: "main")
    ]
}
