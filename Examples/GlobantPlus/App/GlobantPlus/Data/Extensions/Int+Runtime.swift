//
//  Int+Runtime.swift
//  Premiere
//
//  Created by Adolfo Vera Blasco on 10/3/23.
//

import Foundation

extension Array where Element == Int {
    func average() -> Int {
        let amount = self.reduce(0) { $0 + $1 }
        return (self.count == 0 ? 0 : amount / self.count)
    }
}
