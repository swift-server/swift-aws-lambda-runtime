//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 4/1/23.
//

import Foundation

public enum LogoSize {
    case extraSmall
    case small
    case regular
    case large
    case original
}

extension LogoSize: CustomStringConvertible {
    public var description: String {
        switch self {
            case .extraSmall:
                return "w92"
            case .small:
                return "w185"
            case .regular:
                return "w300"
            case .large:
                return "w500"
            case .original:
                return "original"
                
        }
    }
}
