//
//  History.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/15/26.
//

import SwiftData
import Foundation

public enum HistoryMediaType: String, Codable {
    case movie
    case episode
}

@Model
public class History {
    /// we dont make resultid the main id because we may have multiple episodes
    public var id: UUID
    public var resultId: Int
    public var name: String
    public var mediaType: HistoryMediaType
    public var season: Int?
    public var episode: Int?
    public var watchedAt: Date
    public var posterPath: String?
    public var lastStoppedAt: Double?

    public init(
        id: UUID = UUID(),
        resultId: Int,
        name: String,
        mediaType: HistoryMediaType,
        season: Int? = nil,
        episode: Int? = nil,
        posterPath: String? = nil,
        watchedAt: Date = .now,
        lastStoppedAt: Double? = nil
    ) {
        self.id = id
        self.resultId = resultId
        self.name = name
        self.mediaType = mediaType
        self.season = season
        self.episode = episode
        self.posterPath = posterPath
        self.watchedAt = watchedAt
        self.lastStoppedAt = lastStoppedAt
    }
}
