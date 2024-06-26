//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 13/3/23.
//

import Foundation
import SotoDynamoDB

final class DynamoDBInsertRepository: InsertRepository {
    private let dynamoDB: DynamoDB
    
    init(awsClient: AWSClient) {
        self.dynamoDB = DynamoDB(client: awsClient)
    }
    
    func insert(_ favorite: Favorite) throws {
        guard let favoriteTableName = Environment.databaseTableName else {
            throw BackendError.databaseTableNotFound
        }
        
        let dynamoInputItem = DynamoDB.PutItemCodableInput(item: favorite, tableName: favoriteTableName)
        let output = try dynamoDB.putItem(dynamoInputItem).wait()
    }
}
