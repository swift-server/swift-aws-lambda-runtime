//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 12/1/23.
//

import Foundation
import SwiftUI

public struct GlobantPlusTextStyleModifier: ViewModifier {
    private let font: GlobantPlusTextStyleModifier.Font
    private let width: GlobantPlusTextStyleModifier.Width
    private let weight: GlobantPlusTextStyleModifier.Weight
    private let color: Color
    
    init(font: GlobantPlusTextStyleModifier.Font, width: GlobantPlusTextStyleModifier.Width, weight: GlobantPlusTextStyleModifier.Weight) {
        self.font = font
        self.width = width
        self.weight = weight
        self.color = .primary
    }
    
    init(style: GlobantPlusTextStyleModifier.Style) {
        switch style {
            case .largeTitle:
                self.font = .largeTitle
                self.width = .expanded
                self.weight = .bold
                self.color = .primary
            case .title:
                self.font = .title
                self.width = .compressed
                self.weight = .bold
                self.color = .primary
            case .mediaName:
                self.font = .body
                self.width = .standard
                self.weight = .bold
                self.color = .primary
            case .body:
                self.font = .body
                self.width = .standard
                self.weight = .regular
                self.color = .primary
            case .note:
                self.font = .body
                self.width = .standard
                self.weight = .regular
                self.color = .primary
            case .data:
                self.font = .body
                self.width = .compressed
                self.weight = .regular
                self.color = .primary
        }
    }
    
    public func body(content: Content) -> some View {
        content
            .font(self.font.value)
            .fontWidth(self.width.fontWidth)
            .fontWeight(self.weight.fontWeight)
            .foregroundColor(self.color)
    }
    
}

extension GlobantPlusTextStyleModifier {
    public enum Style {
        case largeTitle
        case title
        case mediaName
        case body
        case note
        case data
    }
    
    public enum Font {
        case largeTitle
        case title
        case body
        case note
        
        var value: SwiftUI.Font {
            switch self {
                case .largeTitle:
                    return .largeTitle
                case .title:
                    return .title
                case .body:
                    return .body
                case .note:
                    return .caption
            }
        }
    }
    
    public enum Width {
        case compressed
        case standard
        case expanded
        
        var fontWidth: SwiftUI.Font.Width {
            switch self {
                case .compressed:
                    return .compressed
                case .standard:
                    return .standard
                case .expanded:
                    return .expanded
            }
        }
    }
    
    public enum Weight {
        case regular
        case bold
        case light
        
        var fontWeight: SwiftUI.Font.Weight {
            switch self {
                case .regular:
                    return .regular
                case .bold:
                    return .bold
                case .light:
                    return .light
            }
        }
    }
}
