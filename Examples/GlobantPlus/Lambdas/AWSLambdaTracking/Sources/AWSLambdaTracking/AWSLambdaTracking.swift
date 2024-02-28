import Foundation

import AWSLambdaRuntime
import AWSLambdaEvents

@main
struct AWSLambdaTracking: LambdaHandler {
    init(context: LambdaInitializationContext) async throws {
        // Inicialializamos...
    }
    
    func handle(_ event: SQSEvent, context: LambdaContext) async throws {
        let userStatistics = event.records.compactMap({ event -> UserStatistic? in
            let jsonDecoder = JSONDecoder()
            
            guard let data = event.body.data(using: .utf8),
                  let userStatistics = try? jsonDecoder.decode(UserStatistic.self, from: data)
            else
            {
                return nil
            }
            
            return userStatistics
        })
        
        for userStatistic in userStatistics {
            context.logger.info("😎 \(userStatistic.userId): \(userStatistic.activity) el medio \(userStatistic.mediaId.description)" )
        }
    }
}
