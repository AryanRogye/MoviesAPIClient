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
    case cantAccessSearchUrl

    var errorDescription: String? {
        switch self {
        case .noToken:
            "No Token in Info.plist"
        case .tokenEmpty:
            "Token is empty"
        case .cantAccessSearchUrl:
            "Can't access search url"
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

    public func search(_ text: String) async throws {
        guard let url = URL(string: "https://api.themoviedb.org/3/search/multi") else {
            throw TMDBError.cantAccessSearchUrl
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "query", value: text),
            URLQueryItem(name: "include_adult", value: "true"),
            URLQueryItem(name: "language", value: "en-US"),
            URLQueryItem(name: "page", value: "1"),
        ]

        components.queryItems = components.queryItems.map { $0 + queryItems } ?? queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.allHTTPHeaderFields = [
            "accept": "application/json",
            "Authorization": "Bearer \(token)"
        ]

        let (data, _) = try await URLSession.shared.data(for: request)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let response = try decoder.decode(SearchResponse.self, from: data)
        searchResults = response.results
    }
}
