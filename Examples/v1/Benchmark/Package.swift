// swift-tools-version:5.7

import PackageDescription

// needed for CI to test the local version of the library
import class Foundation.ProcessInfo  
import struct Foundation.URL

let runtimeVersion = Version("1.0.0-alpha.3")

let package = Package(
    name: "swift-aws-lambda-runtime-example",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "MyLambda", targets: ["MyLambda"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: runtimeVersion)
    ],
    targets: [
        .executableTarget(
            name: "MyLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntimeCore", package: "swift-aws-lambda-runtime")
            ],
            path: "."
        )
    ]
)

// for CI to test the local version of the library
// if ProcessInfo.processInfo.environment["LAMBDA_USE_LOCAL_DEPS"] != nil {    
//     print("LAMBDA_USE_LOCAL_DEPS is ignored for runtime v1 examples.")
//     print("This project will compile against runtime version \(runtimeVersion)")
// }

if let localDepsPath = ProcessInfo.processInfo.environment["LAMBDA_USE_LOCAL_DEPS"], localDepsPath != ""  {  

            // check if directory exists
            let u = URL(fileURLWithPath: localDepsPath)
            if let v = try? u.resourceValues(forKeys: [.isDirectoryKey]), v.isDirectory! {
                    print("Compiling against swift-aws-lambda-runtime located at \(localDepsPath)")
                    package.dependencies = [
                       .package(name: "swift-aws-lambda-runtime", path: localDepsPath)
                    ]
            } else {
                print("LAMBDA_USE_LOCAL_DEPS is not pointing to your local swift-aws-lambda-runtime code")
                print("This project will compile against runtime version \(runtimeVersion)")
            }
      
}