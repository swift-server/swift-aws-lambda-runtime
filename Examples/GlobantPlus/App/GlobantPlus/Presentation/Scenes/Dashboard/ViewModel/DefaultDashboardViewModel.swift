//
//  DefaultDashboardViewModel.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 4/1/23.
//

import Foundation

final class DefaultDashboardViewModel: DashboardViewModel, ObservableObject {
    @Published private(set) var trendingShows = [DashboardView.Model]()
    @Published private(set) var trendingMovies = [DashboardView.Model]()
    @Published private(set) var popularDocumentaries = [DashboardView.Model]()
    
    private(set) var useCase = DashboardFacade()
    
    func fetchTrendingShows() async {
        do {
            let shows = try await useCase.fetchTrendingShows()
            
            self.trendingShows = shows.map({ show in
                var model = DashboardView.Model(id: show.id, title: show.title)
                
                model.posterPath = show.posterPath
                model.backdropPath = show.backdropPath
                
                return model
            })
        } catch let error {
            print("🚨 \(error)")
        }
    }
    
    func fetchTrendingMovies() async {
        do {
            let movies = try await useCase.fetchTrendingMovies()
            
            self.trendingMovies = movies.map({ movie in
                var model = DashboardView.Model(id: movie.id, title: movie.title)
                
                model.posterPath = movie.posterPath
                model.backdropPath = movie.backdropPath
                
                return model
            })
        } catch let error {
            print("🚨 \(error)")
        }
    }
    
    func fetchPopularDocumentaries() async {
        do {
            let documentaries = try await useCase.fetchPopularDocumentaries()
            
            self.popularDocumentaries = documentaries.map({ documentary in
                var model = DashboardView.Model(id: documentary.id, title: documentary.title)
                
                model.posterPath = documentary.posterPath
                model.backdropPath = documentary.backdropPath
                
                return model
            })
        } catch let error {
            print("🚨 \(error)")
        }
    }
}
