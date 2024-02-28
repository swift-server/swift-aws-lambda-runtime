//
//  File.swift
//  
//
//  Created by Adolfo Vera Blasco on 6/3/23.
//

import Foundation
import Resty

public extension MovieDB {
    func showDetails(showId: Int) async throws -> MDBShow {
        let response = try await self.get(endpoint: MovieDatabaseEndpoint.show(id: showId))
        
        guard let data = response.data else {
            throw MovieDBError.emptyResults
        }
        do {
            let show_aux = try jsonDecoder.decode(MDBShow.self, from: data)
        } catch let error {
            print(error)
        }
        
        let show = try jsonDecoder.decode(MDBShow.self, from: data)
        
        return show
    }
}
