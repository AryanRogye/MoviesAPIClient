//
//  MoviesSchema.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/17/26.
//

import SwiftData

enum MoviesSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Favorite.self, History.self, Collection.self, CollectionItem.self]
    }
}
