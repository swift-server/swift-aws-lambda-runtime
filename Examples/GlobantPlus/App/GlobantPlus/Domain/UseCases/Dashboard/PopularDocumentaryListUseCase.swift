//
//  PopularDocumentaryListUseCase.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 16/3/23.
//

import Foundation

protocol PopularDocumentaryListUseCase {
    func fetchPopularDocumentaries() async throws -> [TrendingItem]
}
