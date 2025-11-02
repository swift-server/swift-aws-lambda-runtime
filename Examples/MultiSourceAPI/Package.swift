// swift-tools-version:6.2

import PackageDescription

// needed for CI to test the local version of the library
import struct Foundation.URL

let package = Package(
    name: "MultiSourceAPI",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "MultiSourceAPI", targets: ["MultiSourceAPI"])
    ],
    dependencies: [
        .package(url: "https://github.com/awslabs/swift-aws-lambda-runtime.git", from: "2.0.0"),
        .package(url: "https://github.com/awslabs/swift-aws-lambda-events.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "MultiSourceAPI",
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
    let indexToRemove = package.dependencies.firstIndex { dependency in
        switch dependency.kind {
        case .sourceControl(
            name: _,
            location: "https://github.com/awslabs/swift-aws-lambda-runtime.git",
            requirement: _
        ):
            return true
        default:
            return false
        }
    }
    if let indexToRemove {
        package.dependencies.remove(at: indexToRemove)
    }

    print("[INFO] Compiling against swift-aws-lambda-runtime located at \(localDepsPath)")
    package.dependencies += [
        .package(name: "swift-aws-lambda-runtime", path: localDepsPath)
    ]
}
