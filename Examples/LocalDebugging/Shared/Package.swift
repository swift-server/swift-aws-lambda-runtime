// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Shared",
    products: [
        .library(name: "Shared", targets: ["Shared"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "Shared", dependencies: []),
    ]
)
