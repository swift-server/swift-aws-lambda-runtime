//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 13/3/23.
//

import Foundation

enum Environment {
    static let databaseTableName = ProcessInfo.processInfo.environment["DB_TABLE_NAME"]
}
