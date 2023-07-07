//
//  SQSActivityQueue.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 12/3/23.
//

import Foundation
import SotoSQS

final class SQSActivityQueue {
    private let sqs: SQS
    private let awsClient: AWSClient
    
    init() {
        let awsCredentials = CredentialProviderFactory.static(accessKeyId: ApplicationEnvironment.shared.awsAccessKey, secretAccessKey: ApplicationEnvironment.shared.awsSecretAccessKey)
        self.awsClient = AWSClient(credentialProvider: awsCredentials, httpClientProvider: .createNew)
        
        self.sqs = SQS(client: awsClient)
    }
    
    deinit {
        try? awsClient.syncShutdown()
    }
    
    func sendMessageFor(activity: SQSActivity) async {
        let jsonEncoder = JSONEncoder()
        guard let data = try? jsonEncoder.encode(activity),
              let jsonActivity = String(data: data, encoding: .utf8)
        else
        {
            return
        }
        
        let activityMessage = SQS.SendMessageRequest(messageBody: jsonActivity,
                                                     queueUrl: ApplicationEnvironment.shared.awsSQSQueueURL)
        
        do {
            let queueResponse = try await sqs.sendMessage(activityMessage)
            print("👍 SQS message sent with ID \(queueResponse.messageId ?? "none")")
        } catch let error {
            print("🚨 SQS error: \(error)")
        }
    }
}
