//
//  DisplayServerError.swift
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
