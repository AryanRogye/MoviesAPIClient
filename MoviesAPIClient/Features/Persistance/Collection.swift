//
//  Collection.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/17/26.
//

import SwiftData
import Foundation

enum PasswordProtectedCollectionState: Codable {
    case none
    case password([Int])
}

@Model
final class Collection {
    var id: UUID
    var name: String

    var passwordCollectionState: PasswordProtectedCollectionState

    @Relationship(deleteRule: .cascade, inverse: \CollectionItem.collection)
    var results: [CollectionItem]

    init(id: UUID = UUID(), name: String, results: [CollectionItem]) {
        self.id = id
        self.name = name
        self.passwordCollectionState = .none
        self.results = results
    }

    init(id: UUID = UUID(), name: String, passwordCollectionState: PasswordProtectedCollectionState, results: [CollectionItem]) {
        self.id = id
        self.name = name
        self.passwordCollectionState = passwordCollectionState
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
