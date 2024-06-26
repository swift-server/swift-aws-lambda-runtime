//
//  ShowTests.swift
//  
//
//  Created by Adolfo Vera Blasco on 6/3/23.
//

import XCTest
@testable import MovieDB

final class ShowTests: XCTestCase {
    #warning("Copy your MovieDB API here 👇")
    private let client = MovieDB(apiKey: "")
    
    private let shows = [
        1399,  // Juego de Tronos
        73586, // Yellowstone
        66732, // Stranger Things
        100088, // The Last of Us
        153312, // Tulsa King
        456, // The Simpsons
        5920, // El Mentalista
        76479, // The Boys
        78191, // You
        215333, // La chica de nieve
        4586, // Las chicas Gilmore
        4604, // Smallville
        31586, // La Reina del Sur
        1421, // Modern Family
        46260, // Naruto
        31132, // Historias corrientes
        1419, // Castle
        37606, // Gumball
        124364, // From
        1418, // The Big Bang Theory
        95403, // The Peripheral
        90669, // 1899
        1100, // Como conocí a vuestra madre
        126725 // Velma
    ]
    
    func testShow() async {
        for showId in shows {
            do {
                let show = try await client.showDetails(showId: showId)
                
                XCTAssertFalse(show.title.isEmpty)
                XCTAssertEqual(showId, show.id)
            } catch let error {
                print(showId)
                print(error)
                XCTFail(error.localizedDescription)
            }
        }
    }
}
