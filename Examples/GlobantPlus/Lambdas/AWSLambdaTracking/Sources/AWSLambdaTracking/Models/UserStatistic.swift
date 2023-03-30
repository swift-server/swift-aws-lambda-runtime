import Foundation

struct UserStatistic: Decodable {
    let createdAt: Date
    let activity: String
    let mediaId: Int
    let userId: String
}
