//
//  DisplayServerError.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/15/26.
//

import Foundation

public enum DisplayServerError: LocalizedError {
    case cantConstructURL

    public var errorDescription: String? {
        switch self {
        case .cantConstructURL:
            return "Can't construct URL"
        }
    }
}
