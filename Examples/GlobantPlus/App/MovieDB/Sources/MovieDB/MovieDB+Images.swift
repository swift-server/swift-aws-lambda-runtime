//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 4/1/23.
//

import Foundation
import Resty

extension MovieDB {
    public func makePosterUriFrom(path: String?, ofSize size: PosterSize) -> String? {
        guard let path else {
            return nil
        }
        
        return ImageEndpoint.poster(size: size, path: path).path
    }
    
    public func makeBackdropUriFrom(path: String?, ofSize size: BackdropSize) -> String? {
        guard let path else {
            return nil
        }
        
        return ImageEndpoint.backdrop(size: size, path: path).path
    }
    
    public func makeLogoUriFrom(path: String?, ofSize size: LogoSize) -> String? {
        guard let path else {
            return nil
        }
        
        return ImageEndpoint.company(size: size, path: path).path
    }
}
