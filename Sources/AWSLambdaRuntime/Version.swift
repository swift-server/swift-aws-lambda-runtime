//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// The version of the AWS Lambda Runtime.
///
/// This is used in the User Agent header when making requests to the AWS Lambda data Plane.
///
/// - Note: This is a static property that returns the current version of the AWS Lambda Runtime.
///         It is used to ensure that the runtime can be identified by the AWS Lambda service.
///         As such, we mainly care about major version and minor version. Patch and pre-release versions are ignored.
package enum Version {
    /// The current version of the AWS Lambda Runtime.
    package static let current = "2.0"
}
