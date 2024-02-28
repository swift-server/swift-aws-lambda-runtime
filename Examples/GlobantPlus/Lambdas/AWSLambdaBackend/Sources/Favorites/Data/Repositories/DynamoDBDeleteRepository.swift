//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 13/3/23.
//

import Foundation
import SotoDynamoDB

final class DynamoDBDeleteRepository: DeleteRepository {
    private let dynamoDB: DynamoDB
    
    init(awsClient: AWSClient) {
        self.dynamoDB = DynamoDB(client: awsClient)
    }
    
    func delete(_ favorite: Favorite) throws {
        guard let favoriteTableName = Environment.databaseTableName else {
            throw BackendError.databaseTableNotFound
        }
        
        let favoriteKey: [String : DynamoDB.AttributeValue] = [
            "recordID" : .s(favorite.recordID)
        ]
        
        
        let dynamoInputItem = DynamoDB.DeleteItemInput(key: favoriteKey, tableName: favoriteTableName)
        let output = try dynamoDB.deleteItem(dynamoInputItem).wait()
    }
}
