// swift-tools-version:5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SquareNumberLambda",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .executable(name: "SquareNumberLambda", targets: ["SquareNumberLambda"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "1.0.0-alpha"),
    ],
)
