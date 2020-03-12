//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import AWSLambdaEvents
import XCTest

class DynamoDBTests: XCTestCase {
    static let streamEventPayload = """
    {
      "Records": [
        {
          "eventID": "1",
          "eventVersion": "1.0",
          "dynamodb": {
            "ApproximateCreationDateTime": 1.578648338E9,
            "Keys": {
              "Id": {
                "N": "101"
              }
            },
            "NewImage": {
              "Message": {
                "S": "New item!"
              },
              "Id": {
                "N": "101"
              }
            },
            "StreamViewType": "NEW_AND_OLD_IMAGES",
            "SequenceNumber": "111",
            "SizeBytes": 26
          },
          "awsRegion": "eu-central-1",
          "eventName": "INSERT",
          "eventSourceARN": "arn:aws:dynamodb:eu-central-1:account-id:table/ExampleTableWithStream/stream/2015-06-27T00:48:05.899",
          "eventSource": "aws:dynamodb"
        },
        {
          "eventID": "2",
          "eventVersion": "1.0",
          "dynamodb": {
            "ApproximateCreationDateTime": 1.578648338E9,
            "OldImage": {
              "Message": {
                "S": "New item!"
              },
              "Id": {
                "N": "101"
              }
            },
            "SequenceNumber": "222",
            "Keys": {
              "Id": {
                "N": "101"
              }
            },
            "SizeBytes": 59,
            "NewImage": {
              "Message": {
                "S": "This item has changed"
              },
              "Id": {
                "N": "101"
              }
            },
            "StreamViewType": "NEW_AND_OLD_IMAGES"
          },
          "awsRegion": "eu-central-1",
          "eventName": "MODIFY",
          "eventSourceARN": "arn:aws:dynamodb:eu-central-1:account-id:table/ExampleTableWithStream/stream/2015-06-27T00:48:05.899",
          "eventSource": "aws:dynamodb"
        },
        {
          "eventID": "3",
          "eventVersion": "1.0",
          "dynamodb": {
            "ApproximateCreationDateTime":1.578648338E9,
            "Keys": {
              "Id": {
                "N": "101"
              }
            },
            "SizeBytes": 38,
            "SequenceNumber": "333",
            "OldImage": {
              "Message": {
                "S": "This item has changed"
              },
              "Id": {
                "N": "101"
              }
            },
            "StreamViewType": "NEW_AND_OLD_IMAGES"
          },
          "awsRegion": "eu-central-1",
          "eventName": "REMOVE",
          "eventSourceARN": "arn:aws:dynamodb:eu-central-1:account-id:table/ExampleTableWithStream/stream/2015-06-27T00:48:05.899",
          "eventSource": "aws:dynamodb"
        }
      ]
    }
    """

    func testScheduledEventFromJSON() {
        let data = DynamoDBTests.streamEventPayload.data(using: .utf8)!
        do {
            let event = try JSONDecoder().decode(DynamoDB.Event.self, from: data)

            XCTAssertEqual(event.records.count, 3)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
