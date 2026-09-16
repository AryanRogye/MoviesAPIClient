//
//  History.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/15/26.
//

import SwiftData
import Foundation

enum HistoryMediaType: String, Codable {
    case movie
    case episode
}

@Model
class History {
    /// we dont make resultid the main id because we may have multiple episodes
    var id: UUID
    var resultId: Int
    var name: String
    var mediaType: HistoryMediaType
    var season: Int?
    var episode: Int?
    var watchedAt: Date
    var posterPath: String?

    init(
        id: UUID = UUID(),
        resultId: Int,
        name: String,
        mediaType: HistoryMediaType,
        season: Int? = nil,
        episode: Int? = nil,
        posterPath: String? = nil,
        watchedAt: Date = .now
    ) {
        self.id = id
        self.resultId = resultId
        self.name = name
        self.mediaType = mediaType
        self.season = season
        self.episode = episode
        self.posterPath = posterPath
        self.watchedAt = watchedAt
    }
}
