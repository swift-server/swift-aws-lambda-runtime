//
//  Trackable.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 13/3/23.
//

import Foundation

protocol Trackable {
    func trackUser(_ userID: String, activity: String, relatedToMedia mediaID: Int)
}

extension Trackable {
    func trackUser(_ userID: String, activity: String, relatedToMedia mediaID: Int) {
        let record = SQSActivity(createdAt: Date(),
                                 activity: activity,
                                 mediaId: mediaID,
                                 userId: userID)
        
        let sqs = SQSActivityQueue()
        
        Task(priority: .background) {
            await sqs.sendMessageFor(activity: record)
        }
    }
}
