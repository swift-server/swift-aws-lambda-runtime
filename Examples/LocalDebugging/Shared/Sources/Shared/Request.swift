//
//  Request.swift
//  
//
//  Created by Roshan sah on 24/07/20.
//

import Foundation

public struct Request: Codable, CustomStringConvertible {
    public let name: String
    public let password: String

    public init(name: String, password: String) {
        self.name = name
        self.password = password
    }

    public var description: String {
        "name: \(self.name), password: ***"
    }
}
