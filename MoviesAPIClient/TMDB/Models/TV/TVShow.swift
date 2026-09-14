//
//  TVShow.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import Foundation

struct TVShow: Decodable {
    let id: Int
    let name: String
    let overview: String
    let numberOfEpisodes: Int
    let numberOfSeasons: Int
    let seasons: [Season]
}

struct Season: Decodable, Identifiable, Equatable {
    let id: Int
    let name: String
    let seasonNumber: Int
    let episodeCount: Int
    let posterPath: String?
}
