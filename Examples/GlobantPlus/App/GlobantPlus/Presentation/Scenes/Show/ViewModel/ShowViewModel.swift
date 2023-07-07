//
//  ShowViewModel.swift
//  GlobantPlus
//
//  Created by Adolfo Vera Blasco on 6/3/23.
//

import Foundation

protocol ShowViewModelInput {
    func fetchInformationFor(show id: Int) async
    func manageFavoriteState()
}

protocol ShowViewModelOutput {
    var show: ShowView.Model { get }
}

typealias ShowViewModel = ShowViewModelInput & ShowViewModelOutput
