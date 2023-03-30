//
//  SwiftUIView.swift
//  
//
//  Created by Adolfo Vera Blasco on 12/1/23.
//

import SwiftUI

public struct ShowBackdrop: View {
    public var imagePath: String?
    public var title: String
    public var tagline: String
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Backdrop(path: imagePath)
                .cornerRadius(8)
                .shadow(radius: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Text(title)
                .premiereTextStyle(.mediaName)
                .padding(.horizontal, 8)
            
            Text(tagline)
                .premiereTextStyle(.data)
                .padding(.horizontal, 8)
        }
    }
    
    public init(imagePath: String? = nil, title: String, tagline: String) {
        self.imagePath = imagePath
        self.title = title
        self.tagline = tagline
    }
}

struct ShowBackdrop_Previews: PreviewProvider {
    static var previews: some View {
        ShowBackdrop(imagePath: "https://www.themoviedb.org/t/p/original/tLwEXm2nG64Tce00d59rPNI8ePh.jpg", title: "The Americans", tagline: "Thriller, Adventure")
            .frame(width: 375)
    }
}
