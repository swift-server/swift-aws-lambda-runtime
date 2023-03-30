//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 13/3/23.
//

import Foundation

struct Favorite: Codable {
    let recordID: String
    let userID: String
    let showID: Int
    
    init(user: String, show: Int) {
        self.userID = user
        self.showID = show
        self.recordID = "\(user)-\(show.description)"
    }
    
}
