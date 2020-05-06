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

import AWSLambdaRuntime
import Dispatch
import Foundation
#if canImport(FoundationNetworking) && canImport(FoundationXML)
import FoundationNetworking
import FoundationXML
#endif
import Logging

// MARK: - Run Lambda

Lambda.run { (context: Lambda.Context, _: Request, callback: @escaping (Result<[Exchange], Error>) -> Void) in
    let calculator = ExchangeRatesCalculator()
    calculator.run(logger: context.logger, callback: callback)
}

// MARK: - Business Logic

// This is a contrived example performing currency exchange rate lookup and conversion using URLSession and XML parsing
struct ExchangeRatesCalculator {
    static let currencies = ["EUR", "USD", "JPY"]
    static let currenciesEmojies = [
        "EUR": "💶",
        "JPY": "💴",
        "USD": "💵",
    ]

    let locale: Locale
    let calendar: Calendar

    init() {
        // This is data from HMRC, the UK tax authority. Therefore we want to use their locale when interpreting data from the server.
        self.locale = Locale(identifier: "en_GB")
        // Use the UK calendar, not the system one.
        var calendar = self.locale.calendar
        calendar.timeZone = TimeZone(identifier: "UTC")!
        self.calendar = calendar
    }

    func run(logger: Logger, callback: @escaping (Result<[Exchange], Swift.Error>) -> Void) {
        let startDate = Date()
        let months = (1 ... 12).map {
            self.calendar.date(byAdding: DateComponents(month: -$0), to: startDate)!
        }

        self.download(logger: logger,
                      months: months,
                      monthIndex: months.startIndex,
                      currencies: Self.currencies,
                      state: [:]) { result in

            switch result {
            case .failure(let error):
                return callback(.failure(error))
            case .success(let downloadedDataByMonth):
                logger.debug("Downloads complete")

                var result = [Exchange]()
                var previousData: [String: Decimal?] = [:]
                for (_, exchangeRateData) in downloadedDataByMonth.filter({ $1.period != nil }).sorted(by: { $0.key < $1.key }) {
                    for (currencyCode, rate) in exchangeRateData.ratesByCurrencyCode.sorted(by: { $0.key < $1.key }) {
                        if let rate = rate, let currencyEmoji = Self.currenciesEmojies[currencyCode] {
                            let change: Exchange.Change
                            switch previousData[currencyCode] {
                            case .some(.some(let previousRate)) where rate > previousRate:
                                change = .up
                            case .some(.some(let previousRate)) where rate < previousRate:
                                change = .down
                            case .some(.some(let previousRate)) where rate == previousRate:
                                change = .none
                            default:
                                change = .unknown
                            }
                            result.append(Exchange(date: exchangeRateData.period!.start,
                                                   from: .init(symbol: "GBP", emoji: "💷"),
                                                   to: .init(symbol: currencyCode, emoji: currencyEmoji),
                                                   rate: rate,
                                                   change: change))
                        }
                    }
                    previousData = exchangeRateData.ratesByCurrencyCode
                }
                callback(.success(result))
            }
        }
    }

    private func download(logger: Logger,
                          months: [Date],
                          monthIndex: Array<Date>.Index,
                          currencies: [String],
                          state: [Date: ExchangeRates],
                          callback: @escaping ((Result<[Date: ExchangeRates], Swift.Error>) -> Void)) {
        if monthIndex == months.count {
            return callback(.success(state))
        }

        var newState = state

        let month = months[monthIndex]
        let url = self.exchangeRatesURL(forMonthContaining: month)
        logger.debug("requesting exchange rate from \(url)")
        let dataTask = URLSession.shared.dataTask(with: url) { data, _, error in
            do {
                guard let data = data else {
                    throw error!
                }
                let exchangeRates = try self.parse(data: data, currencyCodes: Set(currencies))
                newState[month] = exchangeRates
                logger.debug("Finished downloading month: \(month)")
                if let period = exchangeRates.period {
                    logger.debug("Got data covering period: \(period)")
                }
            } catch {
                return callback(.failure(error))
            }
            self.download(logger: logger,
                          months: months,
                          monthIndex: monthIndex.advanced(by: 1),
                          currencies: currencies,
                          state: newState,
                          callback: callback)
        }
        dataTask.resume()
    }

    private func parse(data: Data, currencyCodes: Set<String>) throws -> ExchangeRates {
        let document = try XMLDocument(data: data)
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "Etc/UTC")!
        dateFormatter.dateFormat = "dd/MMM/yy"
        let interval: DateInterval?
        if let period = try document.nodes(forXPath: "/exchangeRateMonthList/@Period").first?.stringValue,
            period.count == 26 {
            // "01/Sep/2018 to 30/Sep/2018"
            let startString = period[period.startIndex ..< period.index(period.startIndex, offsetBy: 11)]
            let to = period[startString.endIndex ..< period.index(startString.endIndex, offsetBy: 4)]
            let endString = period[to.endIndex ..< period.index(to.endIndex, offsetBy: 11)]
            if let startDate = dateFormatter.date(from: String(startString)),
                let startDay = calendar.dateInterval(of: .day, for: startDate),
                to == " to ",
                let endDate = dateFormatter.date(from: String(endString)),
                let endDay = calendar.dateInterval(of: .day, for: endDate) {
                interval = DateInterval(start: startDay.start, end: endDay.end)
            } else {
                interval = nil
            }
        } else {
            interval = nil
        }

        let ratesByCurrencyCode: [String: Decimal?] = Dictionary(uniqueKeysWithValues: try currencyCodes.map {
            let xpathCurrency = $0.replacingOccurrences(of: "'", with: "&apos;")
            if let rateString = try document.nodes(forXPath: "/exchangeRateMonthList/exchangeRate/currencyCode[text()='\(xpathCurrency)']/../rateNew/text()").first?.stringValue,
                // We must parse the decimal data using the UK locale, not the system one.
                let rate = Decimal(string: rateString, locale: self.locale) {
                return ($0, rate)
            } else {
                return ($0, nil)
            }
        })

        return (period: interval, ratesByCurrencyCode: ratesByCurrencyCode)
    }

    private func makeUTCDateFormatter(dateFormat: String) -> DateFormatter {
        let utcTimeZone = TimeZone(identifier: "UTC")!
        let result = DateFormatter()
        result.locale = Locale(identifier: "en_US_POSIX")
        result.timeZone = utcTimeZone
        result.dateFormat = dateFormat
        return result
    }

    private func exchangeRatesURL(forMonthContaining date: Date) -> URL {
        let exchangeRatesBaseURL = URL(string: "https://www.hmrc.gov.uk/softwaredevelopers/rates")!
        let dateFormatter = self.makeUTCDateFormatter(dateFormat: "MMyy")
        return exchangeRatesBaseURL.appendingPathComponent("exrates-monthly-\(dateFormatter.string(from: date)).xml")
    }

    private typealias ExchangeRates = (period: DateInterval?, ratesByCurrencyCode: [String: Decimal?])

    private struct Error: Swift.Error, CustomStringConvertible {
        let description: String
    }
}

// MARK: - Request and Response

struct Request: Decodable {}

struct Exchange: Encodable {
    @DateCoding
    var date: Date
    let from: Currency
    let to: Currency
    let rate: Decimal
    let change: Change

    struct Currency: Encodable {
        let symbol: String
        let emoji: String
    }

    enum Change: String, Encodable {
        case up
        case down
        case none
        case unknown
    }

    @propertyWrapper
    public struct DateCoding: Encodable {
        public let wrappedValue: Date

        public init(wrappedValue: Date) {
            self.wrappedValue = wrappedValue
        }

        func encode(to encoder: Encoder) throws {
            let string = Self.dateFormatter.string(from: self.wrappedValue)
            var container = encoder.singleValueContainer()
            try container.encode(string)
        }

        private static var dateFormatter: ISO8601DateFormatter {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.timeZone = TimeZone(identifier: "UTC")!
            dateFormatter.formatOptions = [.withYear, .withMonth, .withDashSeparatorInDate]
            return dateFormatter
        }
    }
}
