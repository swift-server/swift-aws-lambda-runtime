//
//  AmazonFavorite.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 15/3/23.
//

import Foundation

struct AmazonFavorite: Encodable {
    let userID: String
    let showID: Int
    let recordID: String
    
    init(media: Int, user: String) {
        self.userID = user
        self.showID = media
        self.recordID = "\(user.description)-\(media)"
    }
    
    func encoded() -> Data? {
        let jsonEncoder = JSONEncoder()
        
        let meEncoded = try? jsonEncoder.encode(self)
        
        return meEncoded
    }
}
