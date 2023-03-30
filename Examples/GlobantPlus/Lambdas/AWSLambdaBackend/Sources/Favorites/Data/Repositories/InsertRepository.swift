//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 13/3/23.
//

import Foundation

protocol InsertRepository {
    func insert(_ favorite: Favorite) throws
}
