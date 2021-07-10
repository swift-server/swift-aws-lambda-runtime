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
    static let streamEventBody = """
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

    func testEventFromJSON() {
        let data = DynamoDBTests.streamEventBody.data(using: .utf8)!
        var event: DynamoDBEvent?
        XCTAssertNoThrow(event = try JSONDecoder().decode(DynamoDBEvent.self, from: data))

        XCTAssertEqual(event?.records.count, 3)
    }

    // MARK: - Parse Attribute Value Tests -

    func testAttributeValueBoolDecoding() {
        let json = "{\"BOOL\": true}"
        var value: DynamoDBEvent.AttributeValue?
        XCTAssertNoThrow(value = try JSONDecoder().decode(DynamoDBEvent.AttributeValue.self, from: json.data(using: .utf8)!))
        XCTAssertEqual(value, .boolean(true))
    }

    func testAttributeValueBinaryDecoding() {
        let json = "{\"B\": \"YmFzZTY0\"}"
        var value: DynamoDBEvent.AttributeValue?
        XCTAssertNoThrow(value = try JSONDecoder().decode(DynamoDBEvent.AttributeValue.self, from: json.data(using: .utf8)!))
        XCTAssertEqual(value, .binary([UInt8]("base64".utf8)))
    }

    func testAttributeValueBinarySetDecoding() {
        let json = "{\"BS\": [\"YmFzZTY0\", \"YWJjMTIz\"]}"
        var value: DynamoDBEvent.AttributeValue?
        XCTAssertNoThrow(value = try JSONDecoder().decode(DynamoDBEvent.AttributeValue.self, from: json.data(using: .utf8)!))
        XCTAssertEqual(value, .binarySet([[UInt8]("base64".utf8), [UInt8]("abc123".utf8)]))
    }

    func testAttributeValueStringDecoding() {
        let json = "{\"S\": \"huhu\"}"
        var value: DynamoDBEvent.AttributeValue?
        XCTAssertNoThrow(value = try JSONDecoder().decode(DynamoDBEvent.AttributeValue.self, from: json.data(using: .utf8)!))
        XCTAssertEqual(value, .string("huhu"))
    }

    func testAttributeValueStringSetDecoding() {
        let json = "{\"SS\": [\"huhu\", \"haha\"]}"
        var value: DynamoDBEvent.AttributeValue?
        XCTAssertNoThrow(value = try JSONDecoder().decode(DynamoDBEvent.AttributeValue.self, from: json.data(using: .utf8)!))
        XCTAssertEqual(value, .stringSet(["huhu", "haha"]))
    }

    func testAttributeValueNullDecoding() {
        let json = "{\"NULL\": true}"
        var value: DynamoDBEvent.AttributeValue?
        XCTAssertNoThrow(value = try JSONDecoder().decode(DynamoDBEvent.AttributeValue.self, from: json.data(using: .utf8)!))
        XCTAssertEqual(value, .null)
    }

    func testAttributeValueNumberDecoding() {
        let json = "{\"N\": \"1.2345\"}"
        var value: DynamoDBEvent.AttributeValue?
        XCTAssertNoThrow(value = try JSONDecoder().decode(DynamoDBEvent.AttributeValue.self, from: json.data(using: .utf8)!))
        XCTAssertEqual(value, .number("1.2345"))
    }

    func testAttributeValueNumberSetDecoding() {
        let json = "{\"NS\": [\"1.2345\", \"-19\"]}"
        var value: DynamoDBEvent.AttributeValue?
        XCTAssertNoThrow(value = try JSONDecoder().decode(DynamoDBEvent.AttributeValue.self, from: json.data(using: .utf8)!))
        XCTAssertEqual(value, .numberSet(["1.2345", "-19"]))
    }

    func testAttributeValueListDecoding() {
        let json = "{\"L\": [{\"NS\": [\"1.2345\", \"-19\"]}, {\"S\": \"huhu\"}]}"
        var value: DynamoDBEvent.AttributeValue?
        XCTAssertNoThrow(value = try JSONDecoder().decode(DynamoDBEvent.AttributeValue.self, from: json.data(using: .utf8)!))
        XCTAssertEqual(value, .list([.numberSet(["1.2345", "-19"]), .string("huhu")]))
    }

    func testAttributeValueMapDecoding() {
        let json = "{\"M\": {\"numbers\": {\"NS\": [\"1.2345\", \"-19\"]}, \"string\": {\"S\": \"huhu\"}}}"
        var value: DynamoDBEvent.AttributeValue?
        XCTAssertNoThrow(value = try JSONDecoder().decode(DynamoDBEvent.AttributeValue.self, from: json.data(using: .utf8)!))
        XCTAssertEqual(value, .map([
            "numbers": .numberSet(["1.2345", "-19"]),
            "string": .string("huhu"),
        ]))
    }

    func testAttributeValueEmptyDecoding() {
        let json = "{\"haha\": 1}"
        XCTAssertThrowsError(_ = try JSONDecoder().decode(DynamoDBEvent.AttributeValue.self, from: json.data(using: .utf8)!)) { error in
            guard case DecodingError.dataCorrupted = error else {
                XCTFail("Unexpected error: \(String(describing: error))")
                return
            }
        }
    }

    func testAttributeValueEquatable() {
        XCTAssertEqual(DynamoDBEvent.AttributeValue.boolean(true), .boolean(true))
        XCTAssertNotEqual(DynamoDBEvent.AttributeValue.boolean(true), .boolean(false))
        XCTAssertNotEqual(DynamoDBEvent.AttributeValue.boolean(true), .string("haha"))
    }

    // MARK: - DynamoDB Decoder Tests -

    func testDecoderSimple() {
        let value: [String: DynamoDBEvent.AttributeValue] = [
            "foo": .string("bar"),
            "xyz": .number("123"),
        ]

        struct Test: Codable {
            let foo: String
            let xyz: UInt8
        }

        var test: Test?
        XCTAssertNoThrow(test = try DynamoDBEvent.Decoder().decode(Test.self, from: value))
        XCTAssertEqual(test?.foo, "bar")
        XCTAssertEqual(test?.xyz, 123)
    }
}
