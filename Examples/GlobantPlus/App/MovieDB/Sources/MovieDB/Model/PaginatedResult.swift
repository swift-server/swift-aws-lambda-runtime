//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 3/1/23.
//

import Foundation

public struct PaginatedResult<Item: Codable>: Codable {
    var page: Int
    var pageCount: Int
    var resultCount: Int
    var results: [Item]
    
    private enum CodingKeys: String, CodingKey {
        case page
        case pageCount = "total_pages"
        case resultCount = "total_results"
        case results
    }
}
