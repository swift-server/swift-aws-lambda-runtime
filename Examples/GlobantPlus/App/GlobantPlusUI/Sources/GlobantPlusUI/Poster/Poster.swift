//
//  SwiftUIView.swift
//  
//
//  Created by Adolfo Vera Blasco on 4/1/23.
//

import SwiftUI
import UIKit

public struct Poster: View {
    private let posterAspectRatio = 0.6665
    private var url: URL?
    
    public var body: some View {
        AsyncImage(url: url) { status in
            switch status {
                case .empty:
                    Rectangle()
                        .aspectRatio(posterAspectRatio, contentMode: .fit)
                        .background(Color.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(alignment: .center) {
                            ProgressView()
                        }
                case .success(let image):
                    image
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(posterAspectRatio, contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                case .failure:
                    Image("PosterPlaceholder", bundle: Bundle.module)
                        .resizable()
                        .aspectRatio(posterAspectRatio, contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    public init(path: String?) {
        if let path {
            self.url = URL(string: path)
        }
    }
}

struct Poster_Previews: PreviewProvider {
    static var previews: some View {
        Poster(path: "fake")
    }
}
