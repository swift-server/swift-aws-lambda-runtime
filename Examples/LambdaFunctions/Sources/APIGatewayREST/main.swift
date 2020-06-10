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
import AWSLambdaRuntime
import NIO
import Foundation

// MARK: - Run Lambda

struct Comment: Codable {

    var cid: Int
    var uid: Int
    var aid: Int
    var title: String
    var body: String
    var dateTime: Date

    init(cid: Int, uid: Int, aid: Int, title: String, body: String, date: Date) {
        self.cid = cid
        self.uid = uid
        self.aid = aid
        self.title = title
        self.body = body
        self.dateTime = date
    }
}

struct Article: Codable {

    var aid: Int
    var title: String
    var body: String
    var dateTime: Date
    var comments: [Comment]

    init(aid: Int, title: String, body: String, date: Date, comments: [Comment]) {
        self.aid = aid
        self.title = title
        self.body = body
        self.dateTime = date
        self.comments = comments
    }

}

struct TestData {

    var articles: [Article] = []

    init() {
        // Create 3 articles here
        let body1 = "It is a long established fact that a reader will be distracted by the readable content of a page when looking at its layout."
        let body2 = "All the Lorem Ipsum generators on the Internet tend to repeat predefined chunks as necessary, making this the first true generator on the Internet."
        let body3 = "If you are going to use a passage of Lorem Ipsum, you need to be sure there isn't anything embarrassing hidden in the middle of text."
        let article1 = Article(aid: 1, title: "Article 1", body: body1, date: Date(), comments: [])
        let article2 = Article(aid: 2, title: "Article 2", body: body2, date: Date(), comments: [])
        let article3 = Article(aid: 4, title: "Article 3", body: body3, date: Date(), comments: [])
        articles.append(article1)
        articles.append(article2)
        articles.append(article3)
    }
}

Lambda.run(APIGatewayProxyLambda())

// MARK: - Handler, Request and Response

// FIXME: Use proper Event abstractions once added to AWSLambdaRuntime
struct APIGatewayProxyLambda: EventLoopLambdaHandler {
    public typealias In = APIGateway.V2.Request
    public typealias Out = APIGateway.V2.Response

    public func handle(context: Lambda.Context, event: APIGateway.V2.Request) -> EventLoopFuture<APIGateway.V2.Response> {
        context.logger.debug("hello, api rest gateway!")
        
        // Load the test data
        // This is where a DynamoDB table could be monitored to pull in articles instead of loading them locally.
        let testData = TestData()
        // Create an encoder
        let encoder = JSONEncoder()
        var jsonArticles = "No content"
        do {
            let jsonEncodedArticles = try encoder.encode(testData.articles)
            jsonArticles = String(data: jsonEncodedArticles, encoding: .utf8)!
        } catch {
            context.logger.debug("Error")
        }
        
        return context.eventLoop.makeSucceededFuture(APIGateway.V2.Response(statusCode: .ok, body: jsonArticles))
    }
}
