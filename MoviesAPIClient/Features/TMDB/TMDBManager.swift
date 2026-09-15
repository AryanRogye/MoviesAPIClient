//
//  TMDBManager.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import Foundation

enum TMDBError: LocalizedError {
    case noToken
    case tokenEmpty
    case cantConstructUrl
    case cantCreateComponents
    case cantAccessComponentUrl

    var errorDescription: String? {
        switch self {
        case .noToken:
            "No Token in Info.plist"
        case .tokenEmpty:
            "Token is empty"
        case .cantConstructUrl:
            "Cant construct URL"
        case .cantCreateComponents:
            "Can't create URLComponents"
        case .cantAccessComponentUrl:
            "Can't access URL from URLComponents"
        }
    }
}

@Observable
@MainActor
final class TMDBManager {

    private let token: String
    private(set) var searchResults: [SearchResult] = []

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

    public func seasonInfo(for id: Int, seasonNumber: Int) async throws -> SeasonInfo {
        guard let url = URL(string: "https://api.themoviedb.org/3/tv/\(id)/season/\(seasonNumber)") else {
            throw TMDBError.cantConstructUrl
        }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw TMDBError.cantCreateComponents
        }
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "language", value: "en-US"),
        ]
        components.queryItems = components.queryItems.map { $0 + queryItems } ?? queryItems

        guard let componentsUrl = components.url else {
            throw TMDBError.cantAccessComponentUrl
        }
        var request = URLRequest(url: componentsUrl)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.allHTTPHeaderFields = [
            "accept": "application/json",
            "Authorization": "Bearer \(token)"
        ]

        let (data, _) = try await URLSession.shared.data(for: request)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        return try decoder.decode(SeasonInfo.self, from: data)
    }

    public func infoOnTV(for id: Int) async throws -> TVShow {
        guard let url = URL(string: "https://api.themoviedb.org/3/tv/\(id)") else {
            throw TMDBError.cantConstructUrl
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw TMDBError.cantCreateComponents
        }

        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "language", value: "en-US"),
        ]
        components.queryItems = components.queryItems.map { $0 + queryItems } ?? queryItems

        guard let componentsUrl = components.url else {
            throw TMDBError.cantAccessComponentUrl
        }
        var request = URLRequest(url: componentsUrl)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.allHTTPHeaderFields = [
            "accept": "application/json",
            "Authorization": "Bearer \(token)"
        ]

        let (data, _) = try await URLSession.shared.data(for: request)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        return try decoder.decode(TVShow.self, from: data)
    }

    /// Function to search for tv,movie,person
    public func search(_ text: String) async throws {
        guard let url = URL(string: "https://api.themoviedb.org/3/search/multi") else {
            throw TMDBError.cantConstructUrl
        }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw TMDBError.cantCreateComponents
        }
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "query", value: text),
            URLQueryItem(name: "include_adult", value: "true"),
            URLQueryItem(name: "language", value: "en-US"),
            URLQueryItem(name: "page", value: "1"),
        ]

        components.queryItems = components.queryItems.map { $0 + queryItems } ?? queryItems

        guard let componentsUrl = components.url else {
            throw TMDBError.cantAccessComponentUrl
        }

        var request = URLRequest(url: componentsUrl)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.allHTTPHeaderFields = [
            "accept": "application/json",
            "Authorization": "Bearer \(token)"
        ]

        let (data, _) = try await URLSession.shared.data(for: request)
        print(String(decoding: data, as: UTF8.self))

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            let response = try decoder.decode(SearchResponse.self, from: data)
            searchResults = response.results
        } catch {
            print(error)
        }
    }
}
