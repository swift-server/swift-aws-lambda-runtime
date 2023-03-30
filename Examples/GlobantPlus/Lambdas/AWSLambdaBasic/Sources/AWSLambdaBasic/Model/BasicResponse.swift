//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 12/3/23.
//

import Foundation

struct BasicResponse: Codable {
    let salute: String
    
    init(name: String) {
        let developmentLanguage = ProcessInfo.processInfo.environment["DEV_LANG"]
        self.salute = "¡Hola \(name)! 👋. Estoy programada en \(developmentLanguage ?? "🤷‍♂️")"
    }
}
