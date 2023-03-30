//
//  Environment.swift
//  Premiere
//
//  Created by Adolfo Vera Blasco on 3/1/23.
//

import Foundation

final class ApplicationEnvironment {
    enum Keys: String {
        case apiURL = "API_KEY"
        case apiToken = "API_AUTH_KEY"
        case awsAccessKey = "AWS_ACCESS_KEY_ID"
        case awsSecretAccessKey = "AWS_SECRET_ACCESS_KEY"
        case awsSQSQueueURL = "SQS_QUEUE_URL"
        case awsAPIGatewayURL = "API_GATEWAY_URL"
    }
    
    static let shared = ApplicationEnvironment()
    
    let dictionary: [String : Any]?
    
    private init() {
        self.dictionary = Bundle.main.infoDictionary
    }
}

extension ApplicationEnvironment {
    var apiKey: String {
        guard let dictionary = self.dictionary,
              let value = dictionary[Keys.apiURL.rawValue] as? String
        else {
            fatalError("Non value for API_KEY key")
        }
        
        return value
    }
    
    var apiToken: String {
        guard let dictionary = self.dictionary,
              let token = dictionary[Keys.apiToken.rawValue] as? String
        else {
            fatalError("Non value for API_AUTH_KEY key")
        }
        
        return token
    }
    
    var awsAccessKey: String {
        guard let dictionary = self.dictionary,
              let token = dictionary[Keys.awsAccessKey.rawValue] as? String
        else {
            fatalError("Non value for MY_AWS_ACCESS_KEY_ID key")
        }
        
        return token
    }
    
    var awsSecretAccessKey: String {
        guard let dictionary = self.dictionary,
              let token = dictionary[Keys.awsSecretAccessKey.rawValue] as? String
        else {
            fatalError("Non value for MY_AWS_SECRET_ACCESS_KEY key")
        }
        
        return token
    }
    
    var awsAPIGatewayURL: String {
        guard let dictionary = self.dictionary,
              let token = dictionary[Keys.awsAPIGatewayURL.rawValue] as? String
        else {
            fatalError("Non value for API_GATEWAY_URL key")
        }
        
        return token
    }
    
    var awsSQSQueueURL: String {
        guard let dictionary = self.dictionary,
              let token = dictionary[Keys.awsSQSQueueURL.rawValue] as? String
        else {
            fatalError("Non value for AWS_SQS_QUEUE_URL key")
        }
        
        return token
    }
}
