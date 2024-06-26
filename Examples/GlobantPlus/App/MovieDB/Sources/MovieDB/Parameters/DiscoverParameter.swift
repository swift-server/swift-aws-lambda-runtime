//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 9/1/23.
//

import Foundation
import Resty

enum DiscoverParameter {
    case region(code: String)
    case sort(by: SortField, ascendent: Bool)
    case includeAdultContent(value: Bool)
    case year(value: Int)
    case withCasting(values: [String])
    case withCrew(values: [String])
    case genres(values: [Int])
    case primaryReleaseDate(date: Date, greaterThanThisDate: Bool)
}

extension DiscoverParameter: QueryParameter {
    var queryItem: URLQueryItem {
        switch self {
            case .region(let code):
                return URLQueryItem(name: "region", value: code)
            case .sort(let by, let ascendent):
                let suffix = ascendent ? "asc" : "desc"
                return URLQueryItem(name: "sort_by", value: "\(by.description).\(suffix)")
            case .includeAdultContent(let value):
                return URLQueryItem(name: "include_adult", value: "\(value ? "true" : "false")")
            case .year(let value):
                return URLQueryItem(name: "year", value: "\(value)")
            case .withCasting(let values):
                return URLQueryItem(name: "with_cast", value: values.joined(separator: ","))
            case .withCrew(let values):
                return URLQueryItem(name: "with_crew", value: values.joined(separator: ","))
            case .genres(let values):
                let genres = values.map({ "\($0)" })
                                   .joined(separator: ",")
                
                return URLQueryItem(name: "with_genres", value: genres)
            case .primaryReleaseDate(let date, let greaterThanThisDate):
                let suffix = greaterThanThisDate ? "gte" : "lte"
                let dateValue = DateFormatter.movieDatabaseFormatter.string(from: date)
                
                return URLQueryItem(name: "primary_release_date.\(suffix)", value: dateValue)
        }
    }
}
