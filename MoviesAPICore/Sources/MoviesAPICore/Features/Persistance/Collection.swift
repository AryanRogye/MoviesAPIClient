//
//  Collection.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/17/26.
//

import SwiftData
import Foundation

public enum PasswordProtectedCollectionState: Codable {
    case none
    case password([Int])
}

@Model
public final class Collection {
    public var id: UUID
    public var name: String

    public var passwordCollectionState: PasswordProtectedCollectionState

    @Relationship(deleteRule: .cascade, inverse: \CollectionItem.collection)
    public var results: [CollectionItem]

    var fourImagePaths: [String] {
        Array(
            results
                .compactMap(\.posterPath)
                .prefix(4)
        )
    }

    public init(id: UUID = UUID(), name: String, results: [CollectionItem]) {
        self.id = id
        self.name = name
        self.passwordCollectionState = .none
        self.results = results
    }

    public init(id: UUID = UUID(), name: String, passwordCollectionState: PasswordProtectedCollectionState, results: [CollectionItem]) {
        self.id = id
        self.name = name
        self.passwordCollectionState = passwordCollectionState
        self.results = results
    }
}

@Model
public class CollectionItem {
    public var resultId: Int
    public var name: String
    public var mediaType: String
    public var posterPath: String?

    public var collection: Collection?

    public init(resultId: Int, name: String, mediaType: String, posterPath: String? = nil) {
        self.resultId = resultId
        self.name = name
        self.mediaType = mediaType
        self.posterPath = posterPath
    }
}
