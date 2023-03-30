//
//  DashboardView+Model.swift
//  Premiere
//
//  Created by Adolfo Vera Blasco on 4/1/23.
//

import Foundation

extension DashboardView {
    struct Model: Identifiable {
        var id: Int
        var title: String
        
        var posterPath: String?
        var backdropPath: String?
    }
}
