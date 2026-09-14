//
//  TMDBManager.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import Foundation

enum TMDBError: LocalizedError {
    case noToken

    var errorDescription: String? {
        switch self {
        case .noToken:
            "No Token in Info.plist"
        }
    }
}

@Observable
@MainActor
final class TMDBManager {

    let token: String

    init() throws {
        guard let token = Bundle.main.object(
            forInfoDictionaryKey: "APIReadAccessToken"
        ) as? String else {
            throw TMDBError.noToken
        }

        self.token = token
    }
}
