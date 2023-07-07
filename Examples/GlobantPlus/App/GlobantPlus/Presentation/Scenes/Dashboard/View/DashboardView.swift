//
//  DashboardView.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 4/1/23.
//

import SwiftUI
import GlobantPlusUI

struct DashboardView: View {
    @StateObject private var viewModel = DefaultDashboardViewModel()
    
    //@Environment(\.isFocused) var focused: Bool
    
    var body: some View {
        GeometryReader { proxy in
            ScrollView([ .vertical ], showsIndicators: false) {
                Text("Trending Shows")
                    .premiereTextStyle(.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                
                ScrollView([ .horizontal ], showsIndicators: false) {
                    LazyHStack(alignment: .center, spacing: 32) {
                        ForEach(viewModel.trendingShows) { trendingShow in
                            NavigationLink(destination: ShowView(showID: trendingShow.id)) {
                                ShowBackdrop(imagePath: trendingShow.backdropPath, title: trendingShow.title, tagline: "This is a tagline")
                                    .frame(width: 425)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(width: proxy.size.width)
                
                
                Text("Trending Movies")
                    .premiereTextStyle(.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                
                ScrollView([ .horizontal ], showsIndicators: false) {
                    LazyHStack(alignment: .center, spacing: 16) {
                        ForEach(viewModel.trendingMovies) { trendingMovie in
                            NavigationLink(value: trendingMovie.title) {
                                Poster(path: trendingMovie.posterPath)
                                    .cornerRadius(8)
                                    .shadow(radius: 8)
                                    .frame(width: 375)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Text("Trending Documentaries")
                    .premiereTextStyle(.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                
                ScrollView([ .horizontal ], showsIndicators: false) {
                    LazyHStack(alignment: .center, spacing: 32) {
                        ForEach(viewModel.popularDocumentaries) { popularDocumentary in
                            NavigationLink(destination: ShowView(showID: popularDocumentary.id)) {
                                ShowBackdrop(imagePath: popularDocumentary.backdropPath, title: popularDocumentary.title, tagline: "This is a tagline")
                                    .frame(width: 425)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(width: proxy.size.width)
                
                Text("Spain Top 10")
                    .premiereTextStyle(.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
            }
            .task {
                await viewModel.fetchTrendingMovies()
                await viewModel.fetchTrendingShows()
                await viewModel.fetchPopularDocumentaries()
            }
        }
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
