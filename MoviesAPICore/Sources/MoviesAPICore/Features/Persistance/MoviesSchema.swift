//
//  MoviesSchema.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/17/26.
//

import SwiftData

@MainActor
public enum MoviesSchemaV2: @preconcurrency VersionedSchema {
    @MainActor public static var versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [Favorite.self, History.self, Collection.self, CollectionItem.self]
    }
}
