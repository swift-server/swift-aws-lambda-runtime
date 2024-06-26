//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 13/3/23.
//

import Foundation
import SotoDynamoDB

final class DependencyManager {
    private static var awsClient: AWSClient {
        AWSClient(credentialProvider: .environment,
                  httpClientProvider: .createNew)
    }
    
    static func makeDeleteRepository() -> DeleteRepository {
        return DynamoDBDeleteRepository(awsClient: self.awsClient)
    }
    
    static func makeInsertRepository() -> InsertRepository {
        return DynamoDBInsertRepository(awsClient: self.awsClient)
    }
}
