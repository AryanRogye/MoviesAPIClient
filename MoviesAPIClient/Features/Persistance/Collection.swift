//
//  Collection.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/17/26.
//

import SwiftData
import Foundation

@Model
final class Collection {
    var id: Int

    @Relationship(deleteRule: .cascade, inverse: \CollectionItem.collection)
    var results: [CollectionItem]

    init(id: Int, results: [CollectionItem]) {
        self.id = id
        self.results = results
    }
}

@Model
class CollectionItem {
    var resultId: Int
    var name: String
    var mediaType: String
    var posterPath: String?

    var collection: Collection?

    init(resultId: Int, name: String, mediaType: String, posterPath: String? = nil) {
        self.resultId = resultId
        self.name = name
        self.mediaType = mediaType
        self.posterPath = posterPath
    }
}
