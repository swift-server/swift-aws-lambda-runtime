//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 11/1/23.
//

import Foundation

extension DateFormatter {
    static var movieDatabaseFormatter: DateFormatter {
       let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        return formatter
    }
}
