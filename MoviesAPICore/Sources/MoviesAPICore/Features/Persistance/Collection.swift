//
//  Collection.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/17/26.
//

import SwiftData
import Foundation

public enum PasswordProtectedCollectionState: Codable, Equatable {
    case none
    case password([Int])
}

@Model
public final class Collection {
    public var id: UUID
    public var name: String

    @Relationship(deleteRule: .cascade, inverse: \CollectionItem.collection)
    public var results: [CollectionItem]

    private var passwordCollectionStateData: Data = Data()

    @Transient
    public var passwordCollectionState: PasswordProtectedCollectionState {
        get {
            (try? JSONDecoder().decode(PasswordProtectedCollectionState.self, from: passwordCollectionStateData)) ?? .none
        }
        set {
            passwordCollectionStateData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var coverImagePaths: [String] {
        Array(
            results
                .compactMap(\.posterPath)
                .prefix(4)
        )
    }

    public init(id: UUID = UUID(), name: String, results: [CollectionItem]) {
        self.id = id
        self.name = name
        self.passwordCollectionStateData = (try? JSONEncoder().encode(PasswordProtectedCollectionState.none)) ?? Data()
        self.results = results
    }

    public init(id: UUID = UUID(), name: String, passwordCollectionState: PasswordProtectedCollectionState, results: [CollectionItem]) {
        self.id = id
        self.name = name
        self.passwordCollectionStateData = (try? JSONEncoder().encode(passwordCollectionState)) ?? Data()
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
