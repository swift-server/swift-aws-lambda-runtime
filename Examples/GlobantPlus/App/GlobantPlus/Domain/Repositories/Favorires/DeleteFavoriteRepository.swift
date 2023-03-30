//
//  DeleteFavoriteRepository.swift
//  Premiere
//
//  Created by Adolfo Vera Blasco on 11/3/23.
//

import Foundation

protocol DeleteFavoriteRepository {
    func delete(showId: ShowID) throws
}
