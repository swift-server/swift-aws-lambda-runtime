//
//  ShowRepository.swift
//  Premiere
//
//  Created by Adolfo Vera Blasco on 6/3/23.
//

import Foundation

protocol ShowRepository {
    func fetchShow(identifiedAs showId: Int) async throws -> Show
}
