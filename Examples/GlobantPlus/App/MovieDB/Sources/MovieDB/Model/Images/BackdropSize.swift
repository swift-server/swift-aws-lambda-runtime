//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 4/1/23.
//

import Foundation

public enum BackdropSize {
    case small
    case regular
    case large
    case original
}

extension BackdropSize: CustomStringConvertible {
    public var description: String {
        switch self {
            case .small:
                return "w300"
            case .regular:
                return "w780"
            case .large:
                return "w1280"
            case .original:
                return "original"
                
        }
    }
}
