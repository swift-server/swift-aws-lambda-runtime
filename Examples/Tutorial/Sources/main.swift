//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2025 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AWSLambdaRuntime

// the data structure to represent the input parameter
struct Request: Decodable {
    let text: String
}

// the data structure to represent the response parameter
struct Response: Encodable {
    let text: String
    let isPalindrome: Bool
    let message: String
}

// the business function
func isPalindrome(_ text: String) -> Bool {
    let cleanedText = text.lowercased().filter { $0.isLetter }
    return cleanedText == String(cleanedText.reversed())
}

// the lambda handler function
let runtime = LambdaRuntime {
    (event: Request, context: LambdaContext) -> Response in

    let result = isPalindrome(event.text)
    return Response(
        text: event.text,
        isPalindrome: result,
        message: "Your text is \(result ? "a" : "not a") palindrome"
    )
}

// start the runtime
try await runtime.run()
