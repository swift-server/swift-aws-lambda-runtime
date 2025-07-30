// swift-tools-version:6.0

import PackageDescription

// needed for CI to test the local version of the library
import struct Foundation.URL

let package = Package(
    name: "swift-aws-lambda-runtime-example",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "APIGatewayLambda", targets: ["APIGatewayLambda"])
    ],
    dependencies: [
        // during CI, the dependency on local version of swift-aws-lambda-runtime is added dynamically below
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "2.0.0-beta.1"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "APIGatewayLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
            ],
            path: "Sources"
        )
    ]
)

if let localDepsPath = Context.environment["LAMBDA_USE_LOCAL_DEPS"],
    localDepsPath != "",
    let v = try? URL(fileURLWithPath: localDepsPath).resourceValues(forKeys: [.isDirectoryKey]),
    v.isDirectory == true
{
    // when we use the local runtime as deps, let's remove the dependency added above
    let indexToRemove = package.dependencies.firstIndex { dependency in
        if case .sourceControl(
            name: _,
            location: "https://github.com/swift-server/swift-aws-lambda-runtime.git",
            requirement: _
        ) = dependency.kind {
            return true
        }
        return false
    }
    if let indexToRemove {
        package.dependencies.remove(at: indexToRemove)
    }

    // then we add the dependency on LAMBDA_USE_LOCAL_DEPS' path (typically ../..)
    print("[INFO] Compiling against swift-aws-lambda-runtime located at \(localDepsPath)")
    package.dependencies += [
        .package(name: "swift-aws-lambda-runtime", path: localDepsPath)
    ]
}
