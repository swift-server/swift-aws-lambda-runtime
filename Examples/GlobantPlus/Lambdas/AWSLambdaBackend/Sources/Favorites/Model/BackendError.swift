//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 13/3/23.
//

import Foundation

enum BackendError: Error {
    case emptyParameter
    case unexpectedParameter
    case httpMethodNotImplemented
    case databaseTableNotFound
}
