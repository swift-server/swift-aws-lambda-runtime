// swift-tools-version:6.0

import PackageDescription

#if os(macOS)
let platforms: [PackageDescription.SupportedPlatform]? = [.macOS(.v15)]
#else
let platforms: [PackageDescription.SupportedPlatform]? = nil
#endif

// needed for CI to test the local version of the library
import class Foundation.ProcessInfo  
import struct Foundation.URL

let package = Package(
    name: "swift-aws-lambda-runtime-example",
    platforms: platforms,
    products: [
        .executable(name: "MyLambda", targets: ["MyLambda"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "MyLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime")
            ],
            path: "."
        )
    ]
)

if let localDepsPath = ProcessInfo.processInfo.environment["LAMBDA_USE_LOCAL_DEPS"], localDepsPath != ""  {  

    print("++++++++ \(localDepsPath)")

    // check if directory exists
    let u = URL(fileURLWithPath: localDepsPath)
    if let v = try? u.resourceValues(forKeys: [.isDirectoryKey]), v.isDirectory! {
            print("Compiling against swift-aws-lambda-runtime located at \(localDepsPath)")
            package.dependencies = [
                .package(name: "swift-aws-lambda-runtime", path: localDepsPath)
            ]
    } else {
        print("LAMBDA_USE_LOCAL_DEPS is not pointing to your local swift-aws-lambda-runtime code")
        print("This project will compile against the main branch of the Lambda Runtime on GitHub")
    }
} else {
    print("++++++++ NO ENV VAR ")

}
