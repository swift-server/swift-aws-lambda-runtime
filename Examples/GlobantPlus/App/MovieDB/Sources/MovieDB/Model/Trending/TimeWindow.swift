//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 3/1/23.
//

import Foundation

public enum TimeWindow {
    case day
    case week
}

extension TimeWindow: CustomStringConvertible {
    public var description: String {
        switch self {
            case .day:
                return "day"
            case .week:
                return "week"
        }
    }
}
