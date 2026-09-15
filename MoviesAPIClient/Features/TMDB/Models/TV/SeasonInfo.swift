//
//  SeasonInfo.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

struct SeasonInfo: Decodable {
    let id: Int
    let airDate: String?
    let name: String
    let overview: String
    let posterPath: String?
    let seasonNumber: Int
    let episodes: [Episode]
}

struct Episode: Decodable, Identifiable, Equatable {
    let id: Int
    let name: String
    let overview: String

    let episodeNumber: Int
    let seasonNumber: Int

    let airDate: String?
    let runtime: Int?
    let stillPath: String?
}
