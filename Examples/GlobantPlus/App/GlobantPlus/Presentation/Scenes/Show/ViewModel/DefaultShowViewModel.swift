//
//  DefaultShowViewModel.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 6/3/23.
//

import Foundation

final class DefaultShowViewModel: ShowViewModel, ObservableObject, Trackable {
    @Published private(set) var show = ShowView.Model()
    
    private(set) var useCase: ShowUseCase = DefaultShowUseCase()
    private(set) var favoriteUseCase: FavoriteUseCase = DefaultFavoriteUseCase()
/*
    init(useCase: ShowUseCase) {
        self.useCase = useCase
    }
*/
    func fetchInformationFor(show id: Int) async {
        do {
            let domainShow = try await useCase.fetchShow(identifiedAs: id)
            
            var model = ShowView.Model()
            model.id = domainShow.id
            model.title = domainShow.title
            model.tagline = domainShow.tagline
            model.overview = domainShow.overview
            model.backdropPath = domainShow.backdropPath
            model.genres = domainShow.genres.map({ $0.name }).joined(separator: ", ")
            
            model.episodeCount = domainShow.episodeCount
            model.seasonCount = domainShow.seasonCount
            model.episodeRuntime = domainShow.episodeRuntime
            model.voteAverage = domainShow.voteAverage
            
            model.isFavorite = domainShow.isFavorite
            
            self.show = model
        } catch let error {
            print("\(error)")
        }
        
        self.trackUser("Adolfo", activity: "ShowDetails", relatedToMedia: show.id)
    }
    
    func manageFavoriteState() {
        do {
            try self.favoriteUseCase.setFavorite(to: !self.show.isFavorite, for: show.id)
            self.show.isFavorite.toggle()
        } catch let error {
            print("🚨 No podemos actualizar el estado de *favorito* de la serie. \(error)")
        }
        
        self.trackUser("Adolfo", activity: "Favorite", relatedToMedia: show.id)
    }
}
