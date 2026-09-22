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

struct MediaListItemID: Hashable {
    let mediaType: String
    let id: Int32
}

extension MediaListItem {
    var mediaListItemID: MediaListItemID {
        MediaListItemID(mediaType: mediaType.rawValue, id: id)
    }
}

extension Sequence where Element: MediaListItem {
    func deduplicatedByMediaIdentity() -> [Element] {
        var seen = Set<MediaListItemID>()
        return filter { seen.insert($0.mediaListItemID).inserted }
    }
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
