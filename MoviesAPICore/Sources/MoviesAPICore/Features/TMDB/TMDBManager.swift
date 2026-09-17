//
//  TMDBManager.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import Foundation
import Defaults

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
public final class TMDBManager {

    private let tmdbClient: TMDBClientProviding
    private let token: String

    private var fullTrendingResults: [KTTrendingResult] = []
    private var fullPopularMovieResults: [KTMovieListResult] = []
    private var fullTopRatedMovieResults: [KTMovieListResult] = []
    private var fullNowPlayingMovieResults: [KTMovieListResult] = []

    public var trendingResults: [KTTrendingResult] {
        fullTrendingResults.filter { result in
            includeAdult || !result.adult
        }
    }
    public var popularMovies: [KTMovieListResult] {
        fullPopularMovieResults.filter { result in
            includeAdult || !result.adult
        }
    }
    public var topRatedMovies: [KTMovieListResult] {
        fullTopRatedMovieResults.filter { result in
            includeAdult || !result.adult
        }
    }
    public var nowPlayingMovies: [KTMovieListResult] {
        fullNowPlayingMovieResults.filter { result in
            includeAdult || !result.adult
        }
    }

    public private(set) var popularTV: [KTTVListResult] = []
    public private(set) var topRatedTV: [KTTVListResult] = []
    public private(set) var searchResults: [KTSearchResult] = []

    public var includeAdult: Bool = Defaults[.includeAdult] {
        didSet {
            Defaults[.includeAdult] = includeAdult
        }
    }

    public init(tmdbClient: TMDBClientProviding = TMDBClient(), token tokenOverride: String? = nil) throws {
        if let tokenOverride {
            self.tmdbClient = tmdbClient
            self.token = tokenOverride
            return
        }

        guard let token = Bundle.main.object(
            forInfoDictionaryKey: "APIReadAccessToken"
        ) as? String else {
            throw TMDBError.noToken
        }
        if token.isEmpty {
            throw TMDBError.tokenEmpty
        }

        self.tmdbClient = tmdbClient
        self.token = token
    }

    public func clearSearchResults() {
        self.searchResults = []
    }

    public func trending() async throws {
        let response = try await tmdbClient.trending(token: token)

        self.fullTrendingResults = response.results.filter { result in
            includeAdult || !result.adult
        }
    }

    public func nowPlaying() async throws {
        let result = try await tmdbClient.nowPlayingMovies(token: token, page: 1)
        fullNowPlayingMovieResults = result.results
    }

    public func popularMovie() async throws {
        let result = try await tmdbClient.popularMovies(token: token, page: 1)
        fullPopularMovieResults = result.results
    }

    public func popularTV() async throws {
        let result = try await tmdbClient.popularTV(token: token, page: 1)
        popularTV = result.results
    }

    public func topRatedMovie() async throws {
        let result = try await tmdbClient.topRatedMovies(token: token, page: 1)
        fullTopRatedMovieResults = result.results
    }

    public func topRatedTV() async throws {
        let result = try await tmdbClient.topRatedTV(token: token, page: 1)
        topRatedTV = result.results
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
