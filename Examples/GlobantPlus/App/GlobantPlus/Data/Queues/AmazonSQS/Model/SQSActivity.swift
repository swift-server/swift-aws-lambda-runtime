//
//  SQSActivity.swift
//  Premiere
//
//  Created by Adolfo Vera Blasco on 13/3/23.
//

import Foundation

struct SQSActivity: Codable {
    let createdAt: Date
    let activity: String
    let mediaId: Int
    let userId: String
}
