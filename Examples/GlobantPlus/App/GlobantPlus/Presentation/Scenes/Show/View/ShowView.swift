//
//  ShowView.swift
//  Premiere
//
//  Created by Adolfo Vera Blasco on 18/1/23.
//

import SwiftUI
import GlobantPlusUI

struct ShowView: View {
    @StateObject private var viewModel = DefaultShowViewModel()
    
    var showID: Int
    
    var body: some View {
        ZStack {
            Backdrop(path: viewModel.show.backdropPath)
                .edgesIgnoringSafeArea(.all)
                .animation(.easeIn)
            
            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                
                HStack(alignment: .center, spacing: 48) {
                    buttonsSet
                        .frame(width: 350)
                    
                    showOverview
                        .padding(.horizontal, 48)
                    
                    showDetails
                        .frame(width: 350)
                }
            }
            .padding(.bottom, 24)
        }
        .task {
            await viewModel.fetchInformationFor(show: showID)
        }
    }
    
    private var buttonsSet: some View {
        VStack(alignment: .leading, spacing: 24) {
            Button {
                print("")
            } label: {
                Label("Ver episodio", systemImage: "play.fill")
                    .premiereTextStyle(.body)
                    .frame(width: 300)
            }
            .buttonStyle(.borderedProminent)
            
            
            Button {
                viewModel.manageFavoriteState()
            } label: {
                Label(viewModel.show.isFavorite ? "En favoritos" : "Añadir a favoritos",
                      systemImage: viewModel.show.isFavorite ? "checkmark" : "plus")
                    .premiereTextStyle(.body)
                    .frame(width: 300)
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var showOverview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.show.title)
                .premiereTextStyle(.title)
            
            Text(viewModel.show.overview)
                .premiereTextStyle(.body)
                .lineLimit(3)
        }
    }
    
    private var showDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Genres **\(viewModel.show.genres)**")
                .premiereTextStyle(.data)
            
            Text("Seasons \(viewModel.show.seasonCount)")
                .premiereTextStyle(.data)
            
            if viewModel.show.episodeRuntime > 0 {
                Text("\(viewModel.show.episodeRuntime) minutes")
                    .premiereTextStyle(.data)
            }
        }
    }
}

struct ShowView_Previews: PreviewProvider {
    static var previews: some View {
        ShowView(showID: 111_837)
    }
}
