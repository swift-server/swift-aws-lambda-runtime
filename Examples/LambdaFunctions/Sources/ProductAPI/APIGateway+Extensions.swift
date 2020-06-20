//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AWSLambdaEvents
import Foundation

extension APIGateway.V2.Request {
    public func object<T: Codable>() throws -> T {
        let decoder = JSONDecoder()
        guard let body = self.body,
            let dataBody = body.data(using: .utf8)
            else {
                throw APIError.invalidRequest
        }
        return try decoder.decode(T.self, from: dataBody)
    }
}

extension APIGateway.V2.Response {
    
    static let defaultHeaders = [
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "OPTIONS,GET,POST,PUT,DELETE",
        "Access-Control-Allow-Credentials": "true",
    ]
    
    init(with error: Error, statusCode: AWSLambdaEvents.HTTPResponseStatus) {
        
        self.init(
            statusCode: statusCode,
            headers: APIGateway.V2.Response.defaultHeaders,
            multiValueHeaders: nil,
            body: "{\"message\":\"\(String(describing: error))\"}",
            isBase64Encoded: false
        )
    }
    
    init<Out: Encodable>(with object: Out, statusCode: AWSLambdaEvents.HTTPResponseStatus) {
        let encoder = JSONEncoder()
        
        var body: String = "{}"
        if let data = try? encoder.encode(object) {
            body = String(data: data, encoding: .utf8) ?? body
        }
        self.init(
            statusCode: statusCode,
            headers: APIGateway.V2.Response.defaultHeaders,
            multiValueHeaders: nil,
            body: body,
            isBase64Encoded: false
        )
        
    }
    
    init<Out: Encodable>(with result: Result<Out, Error>, statusCode: AWSLambdaEvents.HTTPResponseStatus) {
        switch result {
        case .success(let value):
            self.init(with: value, statusCode: statusCode)
        case .failure(let error):
            self.init(with: error, statusCode: statusCode)
        }
    }
}
