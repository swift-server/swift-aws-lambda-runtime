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
        // Comments are scaffolded out, but not setup.
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

// FIXME: Use proper Event abstractions once added to AWSLambdaRuntime
//#if DEBUG
//try Lambda.withLocalServer(invocationEndpoint: "/articles", {
//    Lambda.run(APIGatewayProxyLambda())
//} )
//#else
//Lambda.run(APIGatewayProxyLambda())
//#endif

Lambda.run(APIGatewayProxyLambda())

// MARK: - Handler, Request and Response

struct APIGatewayProxyLambda: EventLoopLambdaHandler {
    public typealias In = APIGateway.V2.Request
    public typealias Out = APIGateway.V2.Response

    public func handle(context: Lambda.Context, event: APIGateway.V2.Request) -> EventLoopFuture<APIGateway.V2.Response> {
        context.logger.info("[API Gateway Endpoint] Response handler")
        // Load the test data
        // This is where a DynamoDB table could be monitored to pull in articles instead of loading them locally.
        let testData = TestData()
        // Create an JSONEncoder for encoding a JSON response
        let encoder = JSONEncoder()
        
        var code: UInt = 200
        var responseBody: String = ""
        var queryStringDict: [String: String] = [:]
        
        // Nested Processing function for articles
                
        func encodeArticles(aid: Int?, articles: [Article]) -> (UInt, String) {
            var response = (code, "")
            do {
                var articleSubSet = articles
                if let articleID = aid,
                    articleID <= articles.count {
                    articleSubSet = [articles[(articleID - 1)]]
                } else if let articleID = aid,
                    articleID > articles.count {
                    response.0 = 200
                    response.1 = "No articles found"
                    return response
                }
                
                context.logger.info("[API Gateway Endpoint] - articles count: \(articles.count)")
                let jsonEncodedArticles = try encoder.encode(articleSubSet)
                let jsonArticles = String(data: jsonEncodedArticles, encoding: .utf8)!
                response.0 = 200
                response.1 = jsonArticles
                context.logger.info("[API Gateway Endpoint] - JSON articles decoded")
            } catch {
                response.0 = 500
                context.logger.info("[API Gateway Endpoint] - Error encoding articles")
                response.1 = error.localizedDescription
            }
            return response
        }
                
        // GET
        // /articles                  - Load all articles
        // /articles?aid=1            - Load articles by id
        // /articles/1                - Currently will return a 404
        //
        
        let path = event.context.http.path
        let pathArray = path.components(separatedBy: "/")
        let filteredPathArray = pathArray.filter { $0 != "" }
        

        context.logger.info("[API Gateway Endpoint] Response path count: \(filteredPathArray.count)")
        context.logger.info("[API Gateway Endpoint] Response path: \(filteredPathArray[0])")
        
        let queryString = event.queryStringParameters?.description ?? "No query string params"
        if let queryStringMap = event.queryStringParameters {
            queryStringDict = queryStringMap
        }
        
        context.logger.info("[API Gateway Endpoint] event.context.http.path: \(path)")
        // This does make it with event.queryStringParameters?.description: ["aid": "1"]
        context.logger.info("[API Gateway Endpoint] event.queryStringParameters?.description: \(queryString)")
        
        if filteredPathArray.count == 1, filteredPathArray[0] == "articles",
            queryStringDict.count == 0 {
            let response = encodeArticles(aid: nil, articles: testData.articles)
            code = response.0
            responseBody = response.1

        } else if filteredPathArray.count == 1, filteredPathArray[0] == "articles",
            queryStringDict.count == 1, let aid = queryStringDict["aid"] {
            let response = encodeArticles(aid: Int(aid), articles: testData.articles)
            code = response.0
            responseBody = response.1
        } else if filteredPathArray.count == 1, filteredPathArray[0] == "articles",
            queryStringDict.count > 0 {
            // Assume that aid would have been found by now and return no articles found
            responseBody = "No articles found"
        }

        let httpResponseCode = HTTPResponseStatus(code: code)
        return context.eventLoop.makeSucceededFuture(APIGateway.V2.Response(statusCode: httpResponseCode, body: responseBody))
    }
}
