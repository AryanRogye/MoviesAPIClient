//
//  Favorite.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftData

@Model
final class Favorite {
    @Attribute(.unique) var id: Int

    var name: String
    var mediaType: String
    var posterPath: String?

    init(
        id: Int,
        name: String,
        mediaType: String,
        posterPath: String?
    ) {
        self.id = id
        self.name = name
        self.mediaType = mediaType
        self.posterPath = posterPath
    }
}
