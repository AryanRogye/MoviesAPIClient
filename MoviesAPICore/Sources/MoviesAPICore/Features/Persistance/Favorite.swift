//
//  Favorite.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftData

@Model
public final class Favorite {
    @Attribute(.unique) public var id: Int

    public var name: String
    public var mediaType: String
    public var posterPath: String?

    public init(
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
