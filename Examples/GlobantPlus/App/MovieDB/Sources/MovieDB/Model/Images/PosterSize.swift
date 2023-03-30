//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 4/1/23.
//

import Foundation

public enum PosterSize {
    case extraSmall
    case small
    case regular
    case large
    case original
}

extension PosterSize: CustomStringConvertible {
    public var description: String {
        switch self {
            case .extraSmall:
                return "w185"
            case .small:
                return "w342"
            case .regular:
                return "w500"
            case .large:
                return "w780"
            case .original:
                return "original"
                
        }
    }
}
