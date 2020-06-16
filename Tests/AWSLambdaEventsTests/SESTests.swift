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

class SESTests: XCTestCase {
    static let eventBody = """
    {
      "Records": [
        {
          "eventSource": "aws:ses",
          "eventVersion": "1.0",
          "ses": {
            "mail": {
              "commonHeaders": {
                "date": "Wed, 7 Oct 2015 12:34:56 -0700",
                "from": [
                  "Jane Doe <janedoe@example.com>"
                ],
                "messageId": "<0123456789example.com>",
                "returnPath": "janedoe@example.com",
                "subject": "Test Subject",
                "to": [
                  "johndoe@example.com"
                ]
              },
              "destination": [
                "johndoe@example.com"
              ],
              "headers": [
                {
                  "name": "Return-Path",
                  "value": "<janedoe@example.com>"
                },
                {
                  "name": "Received",
                  "value": "from mailer.example.com (mailer.example.com [203.0.113.1]) by inbound-smtp.eu-west-1.amazonaws.com with SMTP id o3vrnil0e2ic28trm7dfhrc2v0cnbeccl4nbp0g1 for johndoe@example.com; Wed, 07 Oct 2015 12:34:56 +0000 (UTC)"
                }
              ],
              "headersTruncated": true,
              "messageId": "5h5auqp1oa1bg49b2q8f8tmli1oju8pcma2haao1",
              "source": "janedoe@example.com",
              "timestamp": "1970-01-01T00:00:00.000Z"
            },
            "receipt": {
              "action": {
                "functionArn": "arn:aws:lambda:eu-west-1:123456789012:function:Example",
                "invocationType": "Event",
                "type": "Lambda"
              },
              "dkimVerdict": {
                "status": "PASS"
              },
              "processingTimeMillis": 574,
              "recipients": [
                "test@swift-server.com",
                "test2@swift-server.com"
              ],
              "spamVerdict": {
                "status": "PASS"
              },
              "spfVerdict": {
                "status": "PROCESSING_FAILED"
              },
              "timestamp": "1970-01-01T00:00:00.000Z",
              "virusVerdict": {
                "status": "FAIL"
              }
            }
          }
        }
      ]
    }
    """

    func testSimpleEventFromJSON() {
        let data = Data(SESTests.eventBody.utf8)
        var event: SES.Event?
        XCTAssertNoThrow(event = try JSONDecoder().decode(SES.Event.self, from: data))

        guard let record = event?.records.first else {
            XCTFail("Expected to have one record")
            return
        }

        XCTAssertEqual(record.eventSource, "aws:ses")
        XCTAssertEqual(record.eventVersion, "1.0")
        XCTAssertEqual(record.ses.mail.commonHeaders.date.description, "2015-10-07 19:34:56 +0000")
        XCTAssertEqual(record.ses.mail.commonHeaders.from[0], "Jane Doe <janedoe@example.com>")
        XCTAssertEqual(record.ses.mail.commonHeaders.messageId, "<0123456789example.com>")
        XCTAssertEqual(record.ses.mail.commonHeaders.returnPath, "janedoe@example.com")
        XCTAssertEqual(record.ses.mail.commonHeaders.subject, "Test Subject")
        XCTAssertEqual(record.ses.mail.commonHeaders.to?[0], "johndoe@example.com")
        XCTAssertEqual(record.ses.mail.destination[0], "johndoe@example.com")
        XCTAssertEqual(record.ses.mail.headers[0].name, "Return-Path")
        XCTAssertEqual(record.ses.mail.headers[0].value, "<janedoe@example.com>")
        XCTAssertEqual(record.ses.mail.headers[1].name, "Received")
        XCTAssertEqual(record.ses.mail.headers[1].value, "from mailer.example.com (mailer.example.com [203.0.113.1]) by inbound-smtp.eu-west-1.amazonaws.com with SMTP id o3vrnil0e2ic28trm7dfhrc2v0cnbeccl4nbp0g1 for johndoe@example.com; Wed, 07 Oct 2015 12:34:56 +0000 (UTC)")
        XCTAssertEqual(record.ses.mail.headersTruncated, true)
        XCTAssertEqual(record.ses.mail.messageId, "5h5auqp1oa1bg49b2q8f8tmli1oju8pcma2haao1")
        XCTAssertEqual(record.ses.mail.source, "janedoe@example.com")
        XCTAssertEqual(record.ses.mail.timestamp.description, "1970-01-01 00:00:00 +0000")

        XCTAssertEqual(record.ses.receipt.action.functionArn, "arn:aws:lambda:eu-west-1:123456789012:function:Example")
        XCTAssertEqual(record.ses.receipt.action.invocationType, "Event")
        XCTAssertEqual(record.ses.receipt.action.type, "Lambda")
        XCTAssertEqual(record.ses.receipt.dkimVerdict.status, .pass)
        XCTAssertEqual(record.ses.receipt.processingTimeMillis, 574)
        XCTAssertEqual(record.ses.receipt.recipients[0], "test@swift-server.com")
        XCTAssertEqual(record.ses.receipt.recipients[1], "test2@swift-server.com")
        XCTAssertEqual(record.ses.receipt.spamVerdict.status, .pass)
        XCTAssertEqual(record.ses.receipt.spfVerdict.status, .processingFailed)
        XCTAssertEqual(record.ses.receipt.timestamp.description, "1970-01-01 00:00:00 +0000")
        XCTAssertEqual(record.ses.receipt.virusVerdict.status, .fail)
    }
}
