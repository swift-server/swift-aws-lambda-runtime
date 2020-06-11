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

// MARK: - Run Lambda

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
    
    // This is where a DynamoDB table could be monitored to pull in articles instead of loading them locally.
    private let testData = TestData()
    
    private func encodeArticles(aid: Int?, articles: [Article], context: Lambda.Context) -> (Int, String) {
        
        var response = (200, "")
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
            let jsonEncodedByteBuffer = try self.encoder.encode(articleSubSet, using: .init())
            
            let jsonArticles = jsonEncodedByteBuffer.getString(at: 0, length: jsonEncodedByteBuffer.readableBytes) ?? "No articles found"
            
            response.0 = 200
            response.1 = jsonArticles
            context.logger.info("[API Gateway Endpoint] - JSON articles decoded")
        } catch {
            response.0 = 500
            context.logger.error("[API Gateway Endpoint] - Error encoding articles")
            response.1 = error.localizedDescription
        }
        return response
    }

    public func handle(context: Lambda.Context, event: APIGateway.V2.Request) -> EventLoopFuture<APIGateway.V2.Response> {
        context.logger.info("[API Gateway Endpoint] Response handler")
        
        var code: UInt = 200
        var responseBody: String = ""
        var queryStringDict: [String: String] = [:]
        
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
            let response = encodeArticles(aid: nil, articles: testData.articles, context: context)
            code = UInt(response.0)
            responseBody = response.1

        } else if filteredPathArray.count == 1, filteredPathArray[0] == "articles",
            queryStringDict.count == 1, let aid = queryStringDict["aid"] {
            let response = encodeArticles(aid: Int(aid), articles: testData.articles, context: context)
            code = UInt(response.0)
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
