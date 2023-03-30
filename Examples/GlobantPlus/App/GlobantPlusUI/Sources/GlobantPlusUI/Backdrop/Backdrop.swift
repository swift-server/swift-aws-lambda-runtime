//
//  SwiftUIView.swift
//  
//
//  Created by Adolfo Vera Blasco on 4/1/23.
//

import SwiftUI

public struct Backdrop: View {
    private let backdropAspectRatio = 1.777
    private var url: URL?
    
    public var body: some View {
        AsyncImage(url: url) { status in
            switch status {
                case .empty:
                    Rectangle()
                        .aspectRatio(backdropAspectRatio, contentMode: .fill)
                        .background(Color.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(alignment: .center) {
                            ProgressView()
                        }
                case .success(let image):
                    image
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(backdropAspectRatio, contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                case .failure:
                    Image("PosterPlaceholder", bundle: Bundle.module)
                        .resizable()
                        .aspectRatio(backdropAspectRatio, contentMode: .fit)
            }
        }
    }
    
    public init(path: String?) {
        if let path {
            self.url = URL(string: path)
        }
    }
}

struct Backdrop_Previews: PreviewProvider {
    static var previews: some View {
        Backdrop(path: "fake")
    }
}
