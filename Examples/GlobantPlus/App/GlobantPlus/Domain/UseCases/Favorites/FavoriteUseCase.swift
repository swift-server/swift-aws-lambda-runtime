//
//  FavoriteUseCase.swift
//  Premiere
//
//  Created by Adolfo Vera Blasco on 11/3/23.
//

import Foundation

protocol FavoriteUseCase {
    func setFavorite(to newState: Bool, for show: ShowID) throws
}
