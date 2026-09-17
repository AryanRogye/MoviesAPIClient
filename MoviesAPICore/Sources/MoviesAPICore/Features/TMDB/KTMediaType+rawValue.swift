//
//  MediaType.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

/// KMP doesnt expose rawValue so we derive it
extension KTMediaType {
    var rawValue: String {
        switch self {
        case .tv:
            "tv"
        case .movie:
            "movie"
        case .person:
            "person"
        default:
            fatalError("No Default Case")
        }
    }
}
