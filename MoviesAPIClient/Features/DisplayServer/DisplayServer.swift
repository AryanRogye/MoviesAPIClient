//
//  DisplayServer.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/15/26.
//

import Foundation

enum DisplayServerError: LocalizedError {
    case cantConstructURL

    var errorDescription: String? {
        switch self {
        case .cantConstructURL:
            return "Can't construct URL"
        }
    }
}

enum DisplayServer: String, CaseIterable {
    case moviesAPI = "MovesAPI"
    case vidFast = "VidFast"

    var baseURL: URL? {
        switch self {
        case .moviesAPI:
            URL(string: "https://moviesapi.to")
        case .vidFast:
            URL(string: "https://vidfast.vc")
        }
    }

    public func loadMovie(
        movieId: Int
    ) throws -> URL {

        guard let baseURL else {
            throw DisplayServerError.cantConstructURL
        }

        let url = baseURL
            .appendingPathComponent("movie")
            .appendingPathComponent(String(movieId))

        return url
    }

    public func loadTvShow(
        showId: Int,
        season: Int,
        episode: Int
    ) throws -> URL {
        guard let baseURL else {
            throw DisplayServerError.cantConstructURL
        }

        let url = baseURL
            .appendingPathComponent("tv")
            .appendingPathComponent(String(showId))
            .appendingPathComponent(String(season))
            .appendingPathComponent(String(episode))

        return url
    }
}
