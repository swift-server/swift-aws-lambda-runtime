// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MovieDB",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "MovieDB",
            type: .dynamic,
            targets: ["MovieDB"]),
    ],
    dependencies: [
        .package(path: "../Resty")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "MovieDB",
            dependencies: [ "Resty" ]),
        .testTarget(
            name: "MovieDBTests",
            dependencies: ["MovieDB"]),
    ]
)
