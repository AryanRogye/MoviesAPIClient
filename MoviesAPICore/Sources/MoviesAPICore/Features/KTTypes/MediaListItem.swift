//
//  MediaListItem.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/18/26.
//

protocol MediaListItem: Equatable {
    var id: Int32 { get }
    var displayName: String { get }
    var posterPath: String? { get }
    var backdropPath: String? { get }
    var mediaType: KTMediaType { get }
}

extension KTMovieListResult: MediaListItem {
    var displayName: String { title }
    var mediaType: KTMediaType { .movie }
}

extension KTTVListResult: MediaListItem {
    var displayName: String { name }
    var mediaType: KTMediaType { .tv }
}

extension KTTrendingResult: MediaListItem {
    var displayName: String { name ?? title ?? "" }
}
