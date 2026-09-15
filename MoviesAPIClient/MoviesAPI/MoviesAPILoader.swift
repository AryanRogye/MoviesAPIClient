//
//  MoviesAPIManager.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import Foundation

enum MoviesAPILoaderError: LocalizedError {
    case cantConstructURL

    var errorDescription: String? {
        switch self {
        case .cantConstructURL:
            return "Can't construct URL"
        }
    }
}

enum MoviesAPILoader {
    public static func loadTvShow(
        showId: Int,
        season: Int,
        episode: Int
    ) throws -> URL {
        guard let url = URL(
            string: "https://moviesapi.to/tv/\(showId)/\(season)/\(episode)"
        ) else {
            throw MoviesAPILoaderError.cantConstructURL
        }

        return url
    }
}
