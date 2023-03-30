//
//  DashboardViewModel.swift
//  Premiere
//
//  Created by Adolfo Vera Blasco on 4/1/23.
//

import Foundation

protocol DashboardViewModelInput {
    func fetchTrendingShows() async
    func fetchTrendingMovies() async
    
    func fetchPopularDocumentaries() async
}

protocol DashboardViewModelOutput {
    var trendingShows: [DashboardView.Model] { get }
    var trendingMovies: [DashboardView.Model] { get }
    var popularDocumentaries: [DashboardView.Model] { get }
}

typealias DashboardViewModel = DashboardViewModelInput & DashboardViewModelOutput
