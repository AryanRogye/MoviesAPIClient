//
//  TMDBManager.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import Foundation
import Defaults
import SharedLogic

enum TMDBError: LocalizedError {
    case noToken
    case tokenEmpty

    var errorDescription: String? {
        switch self {
        case .noToken:
            "No Token in Info.plist"
        case .tokenEmpty:
            "Token is empty"
        }
    }
}

@Observable
@MainActor
final class TMDBManager {

    private let tmdbClient = TMDBClient()
    private let token: String
    private(set) var searchResults: [KTSearchResult] = []

    var includeAdult: Bool = Defaults[.includeAdult] {
        didSet {
            Defaults[.includeAdult] = includeAdult
        }
    }

    init() throws {
        guard let token = Bundle.main.object(
            forInfoDictionaryKey: "APIReadAccessToken"
        ) as? String else {
            throw TMDBError.noToken
        }
        if token.isEmpty {
            throw TMDBError.tokenEmpty
        }

        self.token = token
    }

    public func clearSearchResults() {
        self.searchResults = []
    }

    public func seasonInfo(for id: Int, seasonNumber: Int) async throws -> KTSeasonInfo {
        return try await tmdbClient.seasonInfo(
            id: Int32(id),
            seasonNumber: Int32(seasonNumber),
            token: token
        )
    }

    public func infoOnTV(for id: Int) async throws -> KTTVShow {
        return try await tmdbClient.infoOnTV(id: Int32(id), token: token)
    }

    /// Function to search for tv,movie,person
    public func search(_ text: String) async throws {
        let results = try await tmdbClient.search(query: text, token: token, includeAdult: includeAdult)
        self.searchResults = results.results
    }
}
