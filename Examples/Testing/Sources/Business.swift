//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright SwiftAWSLambdaRuntime project authors
// Copyright (c) Amazon.com, Inc. or its affiliates.
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

extension String {
    /// Returns a new string with the first character capitalized and the remaining characters in lowercase.
    ///
    /// This method capitalizes the first character of the string and converts the remaining characters to lowercase.
    /// It is useful for formatting strings where only the first character should be uppercase.
    ///
    /// - Returns: A new string with the first character capitalized and the remaining characters in lowercase.
    ///
    /// - Example:
    /// ```
    /// let example = "hello world"
    /// print(example.uppercasedFirst()) // Prints "Hello world"
    /// ```
    func uppercasedFirst() -> String {
        let firstCharacter = prefix(1).capitalized
        let remainingCharacters = dropFirst().lowercased()
        return firstCharacter + remainingCharacters
    }
}
