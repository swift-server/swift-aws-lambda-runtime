//
//  SwiftUIView.swift
//  
//
//  Created by Adolfo Vera Blasco on 14/1/23.
//

import SwiftUI

public struct TopPoster: View {
    public enum BagdePosition {
        case top
        case center
        case bottom
        
        var alignment: Alignment {
            switch self {
                case .top:
                    return .topLeading
                case .center:
                    return .leading
                case .bottom:
                    return .bottomLeading
            }
        }
    }
    
    public var imagePath: String?
    public var order: Int
    public var position: TopPoster.BagdePosition
    
    public var body: some View {
        HStack(alignment: .center, spacing: 0) {
            badge
                .frame(maxWidth: .infinity)
            
            Poster(path: imagePath)
                .cornerRadius(8)
                .shadow(radius: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private var badge: some View {
        ZStack(alignment: .center) {
            RoundedRectangle(cornerRadius: 8)
                .foregroundColor(.white)
                .opacity(1.0)
            
            HStack(alignment: .center, spacing: 2) {
                Text("#")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                
                Text("1")
                    .font(.system(size: 60, weight: .black, design: .rounded))
                    .foregroundColor(.black)
            }
        }
    }
    
    public init(path: String?, order: Int, at position: TopPoster.BagdePosition) {
        self.imagePath = path
        self.order = order
        self.position = position
    }
}

struct TopPoster_Previews: PreviewProvider {
    static var previews: some View {
        TopPoster(path: "https://www.themoviedb.org/t/p/original/axb5KzE3cfwmKhnx33wmHJtADM8.jpg",
                  order: 1,
                  at: .top)
            .frame(width: 500)
    }
}
