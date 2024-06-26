//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 12/1/23.
//

import Foundation
import SwiftUI

extension View {
    public func premiereTextStyle(font: GlobantPlusTextStyleModifier.Font = .body, width: GlobantPlusTextStyleModifier.Width = .standard, weight: GlobantPlusTextStyleModifier.Weight = .regular) -> some View {
        modifier(GlobantPlusTextStyleModifier(font: font, width: width, weight: weight))
    }
    
    public func premiereTextStyle(_ customStyle: GlobantPlusTextStyleModifier.Style) -> some View {
        modifier(GlobantPlusTextStyleModifier(style: customStyle))
    }
}
