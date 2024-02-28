//
//  PremiereApp.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 3/1/23.
//

import SwiftUI

@main
struct GlobantPlusApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack {
                    DashboardView()
                        .edgesIgnoringSafeArea([ .horizontal ])
                }
                .tabItem {
                    Image(systemName: "flame")
                }
                
                Text("Search")
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                    }
            }
            .padding(0)
        }
    }
}
